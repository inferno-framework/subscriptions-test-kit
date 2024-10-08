require_relative '../../../../lib/subscriptions_test_kit/suites/subscriptions_r5_backport_r4_server/' \
                 'subscription_rejection/reject_subscriptions_test'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Server::RejectSubscriptionsTest do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('subscriptions_r5_backport_r4_server') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'subscriptions_r5_backport_r4_server') }

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
      sessionId: 'b8cf5547-1dc7-4714-a797-dc2347b93fe2'
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
      sessionId: 'b8cf5547-1dc7-4714-a797-dc2347b93fe2'
    }
  end

  let(:server_endpoint) { 'http://example.com/fhir' }
  let(:server_credentials) do
    {
      access_token: 'SAMPLE_TOKEN',
      refresh_token: 'REFRESH_TOKEN',
      expires_in: 3600,
      client_id: 'CLIENT_ID',
      token_retrieval_time: Time.now.iso8601,
      token_url: 'http://example.com/token'
    }.to_json
  end

  let(:unsupported_subscription_topic) { 'http://fhirserver.org/topics/unsupported-topic' }
  let(:unsupported_subscription_filter) { 'Encounter/unsupported-filter' }
  let(:unsupported_subscription_channel_type) { 'email' }
  let(:unsupported_subscription_channel_endpoint) { 'http://unsupported-email.com' }
  let(:unsupported_subscription_payload_type) { 'application/unsupported+payload' }
  let(:unsupported_subscription_channel_payload_combo) do
    { channel: 'email', payload: 'application/unsupported+payload' }.to_json
  end

  let(:access_token) { 'SAMPLE_TOKEN' }
  let(:subscription_topic_url) { 'http://fhirserver.org/topics/patient-admission' }
  let(:validator_url) { ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL') }

  def entity_result_message(runnable)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .map(&:message)
      .join(' ')
  end

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(
        test_session_id: test_session.id,
        name:,
        value:,
        type: runnable.config.input_type(name) || 'text'
      )
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  def entity_result_message(runnable)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .map(&:message)
      .join(' ')
  end

  describe 'Server Workflow Subscription Test' do
    let(:test) do
      Class.new(SubscriptionsTestKit::SubscriptionsR5BackportR4Server::RejectSubscriptionsTest) do
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
          oauth_credentials :server_credentials
        end

        input :server_endpoint
        input :server_credentials, type: :oauth_credentials
      end
    end

    it 'passes if every Subscription request returns a non 201 response' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_creation_request = stub_request(:post, "#{server_endpoint}/Subscription")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 400, body: subscription_resource.to_json)

      result = run(test, server_endpoint:, server_credentials:, subscription_resource: subscription_resource.to_json,
                         unsupported_subscription_topic:, unsupported_subscription_filter:, unsupported_subscription_channel_type:,
                         unsupported_subscription_channel_endpoint:, unsupported_subscription_payload_type:,
                         unsupported_subscription_channel_payload_combo:)

      expect(result.result).to eq('pass')
      expect(subscription_creation_request).to have_been_made.times(8)
    end

    it 'passes if all Subscription requests return either a non 201 response or an altered Subscription resource' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_creation_request = stub_request(:post, "#{server_endpoint}/Subscription")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 400, body: subscription_resource.to_json).then
        .to_return(status: 201, body: subscription_resource.to_json).then
        .to_return(status: 400, body: subscription_resource.to_json)

      result = run(test, server_endpoint:, server_credentials:, subscription_resource: subscription_resource.to_json,
                         unsupported_subscription_topic:, unsupported_subscription_filter:, unsupported_subscription_channel_type:,
                         unsupported_subscription_channel_endpoint:, unsupported_subscription_payload_type:,
                         unsupported_subscription_channel_payload_combo:)

      expect(result.result).to eq('pass')
      expect(subscription_creation_request).to have_been_made.times(8)
    end

    it 'fails if a Subscription requests returns a 201 response and did not alter the Subscription resource' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['criteria'] = unsupported_subscription_topic

      subscription_creation_request = stub_request(:post, "#{server_endpoint}/Subscription")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 400, body: subscription_resource.to_json).then
        .to_return(status: 201, body: subscription_resource.to_json).then
        .to_return(status: 400, body: subscription_resource.to_json)

      result = run(test, server_endpoint:, server_credentials:, subscription_resource: subscription_resource.to_json,
                         unsupported_subscription_topic:, unsupported_subscription_filter:, unsupported_subscription_channel_type:,
                         unsupported_subscription_channel_endpoint:, unsupported_subscription_payload_type:,
                         unsupported_subscription_channel_payload_combo:)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match("\nSending a Subscription with unsupported `SubscriptionTopic` should be rejected, or the Subscription should be\naltered to fix the unsupported value.")
      expect(subscription_creation_request).to have_been_made.times(8)
    end

    it 'fails if server returns a 201 and did not alter the Subscription resource for channel and payload combo' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel']['type'] = 'email'
      subscription_resource['channel']['payload'] = 'application/unsupported+payload'

      subscription_creation_request = stub_request(:post, "#{server_endpoint}/Subscription")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 400, body: subscription_resource.to_json).then
        .to_return(status: 400, body: subscription_resource.to_json).then
        .to_return(status: 400, body: subscription_resource.to_json).then
        .to_return(status: 400, body: subscription_resource.to_json).then
        .to_return(status: 400, body: subscription_resource.to_json).then
        .to_return(status: 400, body: subscription_resource.to_json).then
        .to_return(status: 400, body: subscription_resource.to_json).then
        .to_return(status: 201, body: subscription_resource.to_json).then

      result = run(test, server_endpoint:, server_credentials:, subscription_resource: subscription_resource.to_json,
                         unsupported_subscription_topic:, unsupported_subscription_filter:, unsupported_subscription_channel_type:,
                         unsupported_subscription_channel_endpoint:, unsupported_subscription_payload_type:,
                         unsupported_subscription_channel_payload_combo:)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to match(
        "\nSending a Subscription with unsupported channel and payload combination should be rejected, or the Subscription should be\naltered to fix the unsupported value."
      )
      expect(subscription_creation_request).to have_been_made.times(8)
    end

    it 'passes if a server alters the Subscription resource for channel and payload combination' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['channel']['type'] = 'email'

      subscription_creation_request = stub_request(:post, "#{server_endpoint}/Subscription")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 400, body: subscription_resource.to_json).then
        .to_return(status: 400, body: subscription_resource.to_json).then
        .to_return(status: 400, body: subscription_resource.to_json).then
        .to_return(status: 400, body: subscription_resource.to_json).then
        .to_return(status: 400, body: subscription_resource.to_json).then
        .to_return(status: 400, body: subscription_resource.to_json).then
        .to_return(status: 400, body: subscription_resource.to_json).then
        .to_return(status: 201, body: subscription_resource.to_json).then

      result = run(test, server_endpoint:, server_credentials:, subscription_resource: subscription_resource.to_json,
                         unsupported_subscription_topic:, unsupported_subscription_filter:, unsupported_subscription_channel_type:,
                         unsupported_subscription_channel_endpoint:, unsupported_subscription_payload_type:,
                         unsupported_subscription_channel_payload_combo:)

      expect(result.result).to eq('pass')
      expect(subscription_creation_request).to have_been_made.times(8)
    end
  end
end
