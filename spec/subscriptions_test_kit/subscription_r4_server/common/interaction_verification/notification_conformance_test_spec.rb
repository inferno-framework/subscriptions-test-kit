require_relative '../../../../../lib/subscriptions_test_kit/suites/subscriptions_r5_backport_r4_server/' \
                 'common/interaction_verification/notification_conformance_test'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Server::NotificationConformanceTest do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('subscriptions_r5_backport_r4_server') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'subscriptions_r5_backport_r4_server') }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:full_resource_notification_bundle) do
    JSON.parse(File.read(File.join(
                           __dir__, '../../../..', 'fixtures', 'full_resource_notification_bundle_example.json'
                         )))
  end

  let(:empty_notification_bundle) do
    JSON.parse(File.read(File.join(
                           __dir__, '../../../..', 'fixtures', 'empty_notification_bundle_example.json'
                         )))
  end

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

  let(:subscription_channel) do
    "#{Inferno::Application['base_url']}/custom/subscriptions_r5_backport_r4_server/subscription/channel/" \
      'notification_listener'
  end
  let(:server_endpoint) { 'http://example.com/fhir/Subscription' }
  let(:access_token) { 'SAMPLE_TOKEN' }
  let(:subscription_id) { '123' }
  let(:criteria_resource_type) { 'Encounter' }
  let(:validator_url) { ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL') }

  def create_request(url: subscription_channel, direction: 'incoming', tags: nil, body: nil, status: 200, headers: nil)
    headers ||= [
      {
        type: 'request',
        name: 'Authorization',
        value: "Bearer #{access_token}"
      }
    ]
    repo_create(
      :request,
      name: 'subscription_notification',
      direction:,
      url:,
      result:,
      test_session_id: test_session.id,
      response_body: body.is_a?(Hash) ? body.to_json : body,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      status:,
      headers:,
      tags:
    )
  end

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

  describe 'Server Workflow Notification Test' do
    let(:test) do
      Class.new(SubscriptionsTestKit::SubscriptionsR5BackportR4Server::NotificationConformanceTest) do
        fhir_resource_validator do
          url ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL')

          cli_context do
            txServer nil
            displayWarnings true
            disableDefaultResourceFetcher true
          end

          igs('hl7.fhir.uv.subscriptions-backport#1.1.0')
        end
      end
    end

    it 'passes if conformant full-resource event-notification sent to Subscription channel' do
      verification_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)

      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'full-resource'],
                     body: subscription_resource, status: 201)
      create_request(tags: ['event-notification', subscription_id], body: full_resource_notification_bundle)
      result = run(test)
      expect(result.result).to eq('pass')
      expect(verification_request).to have_been_made
    end

    it 'passes if conformant empty event-notification sent to Subscription channel' do
      verification_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)

      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'empty'],
                     body: subscription_resource, status: 201)
      create_request(tags: ['event-notification', subscription_id], body: empty_notification_bundle)
      result = run(test)
      expect(result.result).to eq('pass')
      expect(verification_request).to have_been_made
    end

    it 'skips if no Subscription requests were made' do
      create_request(tags: ['event-notification', subscription_id], body: full_resource_notification_bundle)

      result = run(test)
      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No successful Subscription creation request was made in the previous test.')
    end

    it 'skips if no event-notification requests were made' do
      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'full-resource'],
                     body: subscription_resource, status: 201)

      result = run(test)
      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No event-notification requests were made in a previous test as expected.')
    end
  end

  describe 'Server Coverage Full-Resource Notification Test' do
    let(:test) do
      Class.new(SubscriptionsTestKit::SubscriptionsR5BackportR4Server::NotificationConformanceTest) do
        fhir_resource_validator do
          url ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL')

          cli_context do
            txServer nil
            displayWarnings true
            disableDefaultResourceFetcher true
          end

          igs('hl7.fhir.uv.subscriptions-backport#1.1.0')
        end

        config(
          options: { subscription_type: 'full-resource' }
        )
      end
    end

    it 'passes if conformant full-resource event-notification sent to Subscription channel' do
      verification_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)

      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'full-resource'],
                     body: subscription_resource, status: 201)
      create_request(tags: ['event-notification', subscription_id], body: full_resource_notification_bundle)
      result = run(test)
      expect(result.result).to eq('pass')
      expect(verification_request).to have_been_made
    end

    it 'skips if no full-resource Subscription requests were made' do
      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'empty'],
                     body: subscription_resource)

      result = run(test)
      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No successful Subscription creation request was made in the previous test.')
    end
  end
end
