require_relative '../../../../lib/subscriptions_test_kit/suites/subscriptions_r5_backport_r4_server/' \
                 'subscription_rejection/reject_subscription_cross_version_extension_test'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Server::RejectSubscriptionCrossVersionExtensionTest do
  let(:suite_id) { 'subscriptions_r5_backport_r4_server' }
  let(:results_repo) { Inferno::Repositories::Results.new }

  let(:subscription_resource) do
    JSON.parse(File.read(File.join(
                           __dir__, '../../..', 'fixtures', 'subscription_resource_example.json'
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

  let(:server_endpoint) { 'http://example.com/fhir' }
  let(:access_token) { 'SAMPLE_TOKEN' }
  let(:server_credentials) do
    {
      access_token:,
      refresh_token: 'REFRESH_TOKEN',
      expires_in: 3600,
      client_id: 'CLIENT_ID',
      issue_time: Time.now.iso8601,
      token_url: 'http://example.com/token'
    }.to_json
  end

  let(:subscription_topic_url) { 'http://fhirserver.org/topics/patient-admission' }

  def entity_result_message(runnable)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .map(&:message)
      .join(' ')
  end

  describe 'Server Subscription Rejects Cross Version Extension Test' do
    let(:test) do
      Class.new(SubscriptionsTestKit::SubscriptionsR5BackportR4Server::RejectSubscriptionCrossVersionExtensionTest) do
        fhir_resource_validator do
          url ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL')

          cli_context do
            txServer nil
            displayWarnings true
            disableDefaultResourceFetcher true
          end

          igs('hl7.fhir.uv.subscriptions-backport#1.1.0')
        end

        fhir_client do
          url :server_endpoint
          auth_info :server_credentials
        end

        input :server_endpoint
        input :server_credentials, type: :auth_info
      end
    end

    it 'passes if Subscription request returns a non 201 response' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_creation_request = stub_request(:post, "#{server_endpoint}/Subscription")
        .with(
          headers: { Authorization: "Bearer #{access_token}" }
        )
        .to_return(status: 400, body: subscription_resource.to_json)

      result = run(test, server_endpoint:, server_credentials:, subscription_resource: subscription_resource.to_json)

      expect(result.result).to eq('pass')
      expect(subscription_creation_request).to have_been_made.times(1)
    end

    it 'fails if a Subscription requests returns a 201' do
      allow(test).to receive(:suite).and_return(suite)

      stub_request(:post, "#{server_endpoint}/Subscription")
        .with(
          headers: { Authorization: "Bearer #{access_token}" }
        )
        .to_return(status: 201, body: subscription_resource.to_json)

      result = run(test, server_endpoint:, server_credentials:, subscription_resource: subscription_resource.to_json)

      expect(result.result).to eq('fail')
    end
  end
end
