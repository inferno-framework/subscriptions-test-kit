require_relative '../../../../../lib/subscriptions_test_kit/suites/subscriptions_r5_backport_r4_server/' \
                 'event_notification/empty_content/empty_conformance_test'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Server::EmptyConformanceTest do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('subscriptions_r5_backport_r4_server') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:test) { Inferno::Repositories::Tests.new.find('subscriptions_r4_server_empty_conformance') }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'subscriptions_r5_backport_r4_server') }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

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

  let(:subscription_channel) do
    "#{Inferno::Application['base_url']}/custom/subscriptions_r5_backport_r4_server/subscription/channel/" \
      'notification_listener'
  end
  let(:server_endpoint) { 'http://example.com/fhir/Subscription' }
  let(:access_token) { 'SAMPLE_TOKEN' }
  let(:subscription_id) { '123' }
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

  it 'omits if no Subscriptions are for empty Notifications' do
    create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'full-resource'],
                   body: subscription_resource)
    result = run(test)
    expect(result.result).to eq('omit')
    expect(result.result_message).to eq('No Subscriptions sent with notification payload type of `empty`')
  end

  it 'passes if conformant empty notification sent to Subscription channel' do
    create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'empty'],
                   body: subscription_resource)
    create_request(tags: ['event-notification', subscription_id], body: empty_notification_bundle)
    result = run(test)
    expect(result.result).to eq('pass')
  end
end
