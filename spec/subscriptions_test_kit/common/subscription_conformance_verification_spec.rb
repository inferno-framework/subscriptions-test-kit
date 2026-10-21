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

    it 'fails if subscription is not a JSON object' do
      result = run(test, subscription_resource: '[]')

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('The Subscription must be a JSON object.')
    end

    it 'fails if subscription does not contain a channel' do
      subscription_resource.delete('channel')
      result = run(test, subscription_resource: subscription_resource.to_json)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('The Subscription must include a `channel` element.')
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
        output :checked_subscription

        run do
          checked_subscription = server_check_channel(JSON.parse(subscription_resource), access_token)
          output(checked_subscription: checked_subscription.to_json)
          no_error_verification('There were verification errors')
        end
      end
    end

    before do
      Inferno::Repositories::Tests.new.insert(test)
    end

    def checked_headers(result)
      checked_subscription = JSON.parse(result.output_json).find { |o| o['name'] == 'checked_subscription' }['value']
      JSON.parse(checked_subscription)['channel']['header']
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

    it 'renders the channel endpoint warning as prose if the endpoint contains a newline' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel']['endpoint'] = "https://incorrect-url.com\nhttps://other-url.com"

      run(test, subscription_resource: subscription_resource.to_json, access_token:)
      message = entity_result_message(test)
      expect(message).to match('The subscription url was changed from https://incorrect-url.com')
      expect(message.lines.grep(/\A {4,}\S/)).to be_empty
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

    it 'does not warn or change the header if it already has the correct Authorization header' do
      allow(test).to receive(:suite).and_return(suite)

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to_not match(/Authorization header entry/)
      expect(checked_headers(result)).to eq(['Authorization: Bearer SAMPLE_TOKEN'])
    end

    it 'accepts a correct Authorization header whose name has different casing' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel']['header'] = ['authorization: Bearer SAMPLE_TOKEN']

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to_not match(/Authorization header entry/)
      expect(checked_headers(result)).to eq(['authorization: Bearer SAMPLE_TOKEN'])
    end

    it 'warns and adds the Authorization header if the subscription has no header' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel'].delete('header')

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(
        /Tester-provided Subscription updated before use: Added the Authorization header entry in the `header`/
      )
      expect(entity_result_message(test)).to match(
        /field with the Bearer token `SAMPLE_TOKEN` provided in the "Notification Access Token" input/
      )
      expect(checked_headers(result)).to eq(['Authorization: Bearer SAMPLE_TOKEN'])
    end

    it 'warns and replaces an Authorization header with a different token' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel']['header'] = ['Authorization: Bearer INCORRECT_TOKEN']

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(
        /Tester-provided Subscription updated before use: Replaced the Authorization header entry in the `header`/
      )
      expect(entity_result_message(test)).to match(
        /field with the Bearer token `SAMPLE_TOKEN` provided in the "Notification Access Token" input/
      )
      expect(entity_result_message(test)).to_not include('INCORRECT_TOKEN')
      expect(checked_headers(result)).to eq(['Authorization: Bearer SAMPLE_TOKEN'])
    end

    it 'replaces an Authorization header regardless of the casing of its name' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel']['header'] = ['AUTHORIZATION : Bearer INCORRECT_TOKEN']

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(/Replaced the Authorization header entry/)
      expect(checked_headers(result)).to eq(['Authorization: Bearer SAMPLE_TOKEN'])
    end

    it 'replaces every Authorization header and keeps other headers' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel']['header'] = [
        'Authorization: Bearer SAMPLE_TOKEN',
        'X-Custom-Header: value',
        'authorization: Bearer INCORRECT_TOKEN'
      ]

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(/Replaced the Authorization header entry/)
      expect(checked_headers(result)).to eq(['X-Custom-Header: value', 'Authorization: Bearer SAMPLE_TOKEN'])
    end

    [
      'Authorization:Bearer SAMPLE_TOKEN',
      'Authorization: Bearer SAMPLE_TOKEN ',
      'Authorization : Bearer SAMPLE_TOKEN',
      ' Authorization: Bearer SAMPLE_TOKEN'
    ].each do |malformed_header|
      it "replaces a malformed Authorization header with the correct token: '#{malformed_header}'" do
        allow(test).to receive(:suite).and_return(suite)

        subscription_resource['channel']['header'] = [malformed_header]

        result = run(test, subscription_resource: subscription_resource.to_json,
                           access_token:)
        expect(result.result).to eq('pass')
        expect(entity_result_message(test)).to match(/Replaced the Authorization header entry/)
        expect(checked_headers(result)).to eq(['Authorization: Bearer SAMPLE_TOKEN'])
      end
    end

    it 'replaces duplicate correct Authorization headers with a single entry' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel']['header'] = ['Authorization: Bearer SAMPLE_TOKEN'] * 2

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(/Replaced the Authorization header entry/)
      expect(checked_headers(result)).to eq(['Authorization: Bearer SAMPLE_TOKEN'])
    end

    it 'replaces an Authorization header whose scheme Inferno does not recognize' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel']['header'] = ['Authorization: bearer SAMPLE_TOKEN']

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(/Replaced the Authorization header entry/)
      expect(checked_headers(result)).to eq(['Authorization: Bearer SAMPLE_TOKEN'])
    end

    it 'ignores header entries that are not strings when looking for the Authorization header' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel']['header'] = ['', 42, 'Authorization: Bearer SAMPLE_TOKEN']

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)
      expect(result.result).to eq('pass')
      expect(checked_headers(result)).to eq(['', 42, 'Authorization: Bearer SAMPLE_TOKEN'])
    end

    it 'warns and converts a header string with the correct Authorization header into a list' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel']['header'] = 'Authorization: Bearer SAMPLE_TOKEN'

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(
        /Tester-provided Subscription updated before use: incorrect string value for element `header` converted into/
      )
      expect(entity_result_message(test)).to_not match(/Authorization header entry/)
      expect(checked_headers(result)).to eq(['Authorization: Bearer SAMPLE_TOKEN'])
    end

    it 'converts a header string into a list and replaces an Authorization header with a different token' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel']['header'] = 'Authorization: Bearer INCORRECT_TOKEN'

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(/incorrect string value for element `header` converted into/)
      expect(entity_result_message(test)).to match(/Replaced the Authorization header entry/)
      expect(checked_headers(result)).to eq(['Authorization: Bearer SAMPLE_TOKEN'])
    end

    it 'converts a header string into a list and keeps it when adding the Authorization header' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel']['header'] = 'X-Custom-Header: value'

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(/incorrect string value for element `header` converted into/)
      expect(entity_result_message(test)).to match(/Added the Authorization header entry/)
      expect(checked_headers(result)).to eq(['X-Custom-Header: value', 'Authorization: Bearer SAMPLE_TOKEN'])
    end

    [{ 'Authorization' => 'Bearer SAMPLE_TOKEN' }, 42].each do |malformed_header|
      it "fails and leaves the header unchanged if it is neither a list nor a string: #{malformed_header.inspect}" do
        allow(test).to receive(:suite).and_return(suite)

        subscription_resource['channel']['header'] = malformed_header

        result = run(test, subscription_resource: subscription_resource.to_json,
                           access_token:)
        expect(result.result).to eq('fail')
        expect(entity_result_message(test)).to match(
          /The `header` element on the tester-provided Subscription must be a list of strings\./
        )
        expect(checked_headers(result)).to eq(malformed_header)
      end
    end

    [nil, 'rest-hook', []].each do |malformed_channel|
      it "returns the subscription unchanged if the channel is not an object: #{malformed_channel.inspect}" do
        allow(test).to receive(:suite).and_return(suite)

        subscription_resource['channel'] = malformed_channel
        subscription_resource.compact!

        result = run(test, subscription_resource: subscription_resource.to_json,
                           access_token:)
        expect(result.result).to eq('pass')
        expect(entity_result_message(test)).to be_empty
        checked_subscription = JSON.parse(result.output_json).find { |o| o['name'] == 'checked_subscription' }['value']
        expect(JSON.parse(checked_subscription)).to eq(subscription_resource)
      end
    end

    it 'keeps headers whose names only contain Authorization' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel']['header'] = ['X-Authorization: Bearer SAMPLE_TOKEN', 'Authorization-Info: value']

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(/Added the Authorization header entry/)
      expect(checked_headers(result)).to eq(
        ['X-Authorization: Bearer SAMPLE_TOKEN', 'Authorization-Info: value', 'Authorization: Bearer SAMPLE_TOKEN']
      )
    end

    it 'accepts a correct Authorization header whose token contains a colon' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel']['header'] = ['Authorization: Bearer abc:def']

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token: 'abc:def')
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to_not match(/Authorization header entry/)
      expect(checked_headers(result)).to eq(['Authorization: Bearer abc:def'])
    end
  end
end
