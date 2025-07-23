require_relative '../../../../../lib/subscriptions_test_kit/suites/subscriptions_r5_backport_r4_server/' \
                 'event_notification/full_resource_content/full_resource_conformance_test'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Server::FullResourceConformanceTest do
  let(:suite_id) { 'subscriptions_r5_backport_r4_server' }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:full_resource_notification_bundle) do
    JSON.parse(File.read(File.join(
                           __dir__, '../../../..', 'fixtures', 'full_resource_notification_bundle_example.json'
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

  let(:subscription_channel) do
    "#{Inferno::Application['base_url']}/custom/subscriptions_r5_backport_r4_server/subscription/channel/" \
      'notification_listener'
  end
  let(:server_endpoint) { 'http://example.com/fhir/Subscription' }
  let(:access_token) { 'SAMPLE_TOKEN' }
  let(:subscription_id) { '123' }

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

  describe 'Server Coverage Full Resource Notification Test' do
    let(:test) do
      Class.new(SubscriptionsTestKit::SubscriptionsR5BackportR4Server::FullResourceConformanceTest) do
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

    it 'omits if no Subscriptions are for full-resource Notifications' do
      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'empty'],
                     body: subscription_resource)
      result = run(test)
      expect(result.result).to eq('omit')
      expect(result.result_message).to eq('No Subscriptions sent with notification payload type of `full-resource`')
    end

    it 'passes if conformant full-resource notification sent to Subscription channel' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'full-resource'],
                     body: subscription_resource)
      create_request(tags: ['event-notification', subscription_id], body: full_resource_notification_bundle)

      result = run(test)

      expect(result.result).to eq('pass')
      expect(verification_request).to have_been_made
    end
  end
end
