require_relative '../../../lib/subscriptions_test_kit/common/subscription_conformance_verification'

RSpec.describe SubscriptionsTestKit::SubscriptionConformanceVerification, :runnable do
  let(:suite_id) { 'subscriptions_r5_backport_r4_server' }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:access_token) { 'SAMPLE_TOKEN' }
  let(:subscription_resource) do
    JSON.parse(File.read(File.join(
                           __dir__, '../..', 'fixtures', 'subscription_resource_example.json'
                         )))
  end

  let(:operation_outcome_success) do
    {
      outcomes: [{
        issues: []
      }],
      sessionId: test_session.id
    }
  end

  let(:operation_outcome_failure) do
    {
      outcomes: [{
        issues: [{
          level: 'ERROR',
          message: 'Resource does not conform to profile'
        }]
      }],
      sessionId: test_session.id
    }
  end

  def entity_result_message(runnable)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .map(&:message)
      .join(' ')
  end

  describe 'Subscription Verification' do
    let(:test) do
      Class.new(Inferno::Test) do
        include SubscriptionsTestKit::SubscriptionConformanceVerification
        fhir_resource_validator do
          url ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL')

          cli_context do
            txServer nil
            displayWarnings true
            disableDefaultResourceFetcher true
          end

          igs('hl7.fhir.uv.subscriptions-backport#1.1.0')
        end

        input :subscription_resource

        run do
          subscription_verification(subscription_resource)
          no_error_verification('There were verification errors')
        end
      end
    end

    before do
      Inferno::Repositories::Tests.new.insert(test)
    end

    it 'passes if conformant subscription passed in' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      result = run(test, subscription_resource: subscription_resource.to_json)

      expect(result.result).to eq('pass')
      expect(verification_request).to have_been_made
    end

    it 'fails if subscription is not valid json' do
      result = run(test, subscription_resource: '[[')

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Invalid JSON. ')
    end

    it 'fails if subscription channel type is not set to `rest-hook`' do
      subscription_resource['channel']['type'] = 'email'
      result = run(test, subscription_resource: subscription_resource.to_json)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(
        /The `type` element on the Subscription resource must be set to `rest-hook`/
      )
    end

    it 'fails if inputted subscription is not a Subscription resource' do
      subscription_resource['resourceType'] = 'Patient'

      result = run(test, subscription_resource: subscription_resource.to_json)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected resource type: expected Subscription, but received Patient')
    end

    it 'fails if subscription is not a conformant resource' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_failure.to_json)

      result = run(test, subscription_resource: subscription_resource.to_json)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(
        'Resource does not conform to the profile: http://hl7.org/fhir/uv/subscriptions-backport/'
      )
      expect(verification_request).to have_been_made
    end

    it 'warns if subscription contains a cross-version extension' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      subscription_resource['channel']['_type']['extension'].append(
        { url: 'http://hl7.org/fhir/5.0/StructureDefinition/extension-Subscription.timeout',
          valueUnsignedInt: 60 }
      )

      result = run(test, subscription_resource: subscription_resource.to_json)

      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(
        'Cross-version extensions SHOULD NOT be used on R4 subscriptions to describe any elements also described by'
      )
      expect(verification_request).to have_been_made
    end

    it 'fails if subscription does not contain criteria field' do
      allow(test).to receive(:suite).and_return(suite)

      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      subscription_resource.delete('criteria')

      result = run(test, subscription_resource: subscription_resource.to_json)

      expect(result.result).to eq('fail')
      expect(verification_request).to have_been_made
    end

    it 'fails if subscription criteria does not contain valid URL' do
      allow(test).to receive(:suite).and_return(suite)

      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      subscription_resource['criteria'] = ['Invalid Value']
      result = run(test, subscription_resource: subscription_resource.to_json)

      expect(result.result).to eq('fail')
      expect(verification_request).to have_been_made
    end
  end

  describe 'Server Check Channel' do
    let(:test) do
      Class.new(Inferno::Test) do
        include SubscriptionsTestKit::SubscriptionConformanceVerification
        fhir_resource_validator do
          url ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL')

          cli_context do
            txServer nil
            displayWarnings true
            disableDefaultResourceFetcher true
          end

          igs('hl7.fhir.uv.subscriptions-backport#1.1.0')
        end

        input :subscription_resource, :access_token

        run do
          server_check_channel(JSON.parse(subscription_resource), access_token)
          no_error_verification('There were verification errors')
        end
      end
    end

    before do
      Inferno::Repositories::Tests.new.insert(test)
    end

    it 'warns if subscription does not contain the correct channel endpoint' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel']['endpoint'] = 'https://incorrect-url.com'

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(
        'The subscription url was changed from https://incorrect-url.com to'
      )
    end

    it 'warns if subscription does not contain the correct channel payload' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel']['payload'] = 'application/incorrect-type'

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(
        /The `payload` element on the Subscription resource should be set to/
      )
      expect(entity_result_message(test)).to match(
        /The requested Subscription has been updated to use this value./
      )
    end

    it 'warns but does not update if subscription uses application/json payload' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel']['payload'] = 'application/json'

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(
        /The `payload` element on the Subscription resource should be set to/
      )
      expect(entity_result_message(test)).to_not match(
        /The requested Subscription has been updated to use this value./
      )
    end

    it 'warns if subscription does not contain the correct channel header' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel']['header'] = ['Authorization: Bearer INCORRECT_TOKEN']

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(
        /Added the Authorization header field with a Bearer token set to SAMPLE_TOKEN to the `header` field/
      )
    end
  end
end
