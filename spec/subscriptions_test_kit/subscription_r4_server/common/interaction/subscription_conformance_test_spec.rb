require_relative '../../../../../lib/subscriptions_test_kit/suites/subscriptions_r5_backport_r4_server/' \
                 'common/interaction/subscription_conformance_test'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Server::SubscriptionConformanceTest do
  let(:suite_id) { 'subscriptions_r5_backport_r4_server' }
  let(:results_repo) { Inferno::Repositories::Results.new }

  let(:subscription_resource) do
    JSON.parse(File.read(File.join(
                           __dir__, '../../../..', 'fixtures', 'subscription_resource_example.json'
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

  let(:access_token) { 'SAMPLE_TOKEN' }
  # let(:subscription_topic_url) { 'http://fhirserver.org/topics/patient-admission' }

  describe 'Server Workflow Subscription Test' do
    let(:test) do
      Class.new(SubscriptionsTestKit::SubscriptionsR5BackportR4Server::SubscriptionConformanceTest) do
        fhir_resource_validator do
          url ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL')

          cli_context do
            txServer nil
            displayWarnings true
            disableDefaultResourceFetcher true
          end

          igs('hl7.fhir.uv.subscriptions-backport#1.1.0')
        end

        fhir_resource_validator :no_custom_extensions do
          url ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL')

          cli_context do
            txServer nil
            displayWarnings true
            disableDefaultResourceFetcher true
            extensions []
          end

          igs('hl7.fhir.uv.subscriptions-backport#1.1.0')
        end
      end
    end

    def no_custom_extensions_request?(request)
      body = JSON.parse(request.body)
      context = body['validationContext'] || body['cliContext']
      context['extensions'] == []
    end

    it 'passes if conformant subscription passed in' do
      allow(test).to receive(:suite).and_return(suite)

      verification_request = stub_request(:post, validation_url)
        .with { |request| no_custom_extensions_request?(request) }
        .to_return(status: 200, body: operation_outcome_success.to_json)

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)

      expect(result.result).to eq('pass')
      expect(verification_request).to have_been_made
    end

    it 'fails if the validator reports an error, such as for a custom extension' do
      allow(test).to receive(:suite).and_return(suite)

      verification_request = stub_request(:post, validation_url)
        .with { |request| no_custom_extensions_request?(request) }
        .to_return(status: 200, body: operation_outcome_failure.to_json)

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)

      expect(result.result).to eq('fail')
      expect(verification_request).to have_been_made
    end

    [nil, 'rest-hook', []].each do |malformed_channel|
      it "fails if the channel is not an object: #{malformed_channel.inspect}" do
        allow(test).to receive(:suite).and_return(suite)

        subscription_resource['channel'] = malformed_channel
        subscription_resource.compact!

        result = run(test, subscription_resource: subscription_resource.to_json,
                           access_token:)

        expect(result.result).to eq('fail')
        expect(result.result_message).to eq('The Subscription must include a `channel` element.')
      end
    end

    it 'fails if the channel header is neither a list nor a string' do
      allow(test).to receive(:suite).and_return(suite)

      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)
      subscription_resource['channel']['header'] = { 'Authorization' => 'Bearer SAMPLE_TOKEN' }

      result = run(test, subscription_resource: subscription_resource.to_json,
                         access_token:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Subscription resource is not conformant.')
      expect(verification_request).to have_been_made
    end
  end
end
