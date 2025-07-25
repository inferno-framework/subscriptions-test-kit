require_relative '../../../../lib/subscriptions_test_kit/suites/subscriptions_r5_backport_r4_server/' \
                 'handshake_heartbeat/heartbeat_conformance_test'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Server::HandshakeConformanceTest do
  let(:suite_id) { 'subscriptions_r5_backport_r4_server' }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:handshake_bundle) do
    JSON.parse(File.read(File.join(
                           __dir__, '../../..', 'fixtures', 'handshake_bundle_example.json'
                         )))
  end

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

  let(:subscription_channel) do
    "#{Inferno::Application['base_url']}/custom/subscriptions_r5_backport_r4_server/subscription/channel/" \
      'notification_listener'
  end
  let(:subscription_id) { '123' }
  let(:access_token) { 'SAMPLE_TOKEN' }
  let(:channel_type) { 'rest-hook' }

  def create_request(name: nil, tags: nil, direction: nil, url: subscription_channel, body: nil, status: 200,
                     headers: nil)
    headers ||= [
      {
        type: 'request',
        name: 'Authorization',
        value: "Bearer #{access_token}"
      }
    ]
    repo_create(
      :request,
      name:,
      direction:,
      url:,
      result:,
      test_session_id: test_session.id,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      response_body: body.is_a?(Hash) ? body.to_json : body,
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

  describe 'Server Coverage Handshake Test' do
    let(:test) do
      Class.new(SubscriptionsTestKit::SubscriptionsR5BackportR4Server::HandshakeConformanceTest) do
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

    it 'passes if conformant Handshake Bundle sent to Subscription channel' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      create_request(name: 'subscription_create', direction: 'outgoing', tags: ['subscription_creation', 'Workflow'],
                     body: subscription_resource, status: 201)
      create_request(name: 'subscription_handshake', direction: 'incoming', tags: ['handshake', subscription_id],
                     body: handshake_bundle)
      result = run(test)

      expect(result.result).to eq('pass')
      expect(verification_request).to have_been_made.times(1)
    end

    it 'omits if no handshake received and channel type not rest-hook' do
      subscription_resource['channel']['type'] = 'email'
      create_request(name: 'subscription_create', direction: 'outgoing', tags: ['subscription_creation', 'Workflow'],
                     body: subscription_resource, status: 201)

      result = run(test)

      expect(result.result).to eq('omit')
      expect(result.result_message).to eq('No handshake requests were required or received in a previous tests.')
    end

    it 'fails if no handshake received and channel type is rest-hook' do
      create_request(name: 'subscription_create', direction: 'outgoing', tags: ['subscription_creation', 'Workflow'],
                     body: subscription_resource, status: 201)
      result = run(test)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq(
        'Handshake requests are required if a Subscription channel type is `rest-hook`'
      )
    end

    it 'fails if some rest-hook Subscriptions do not receive Handshake Bundle' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      create_request(name: 'subscription_create', direction: 'outgoing', tags: ['subscription_creation', 'Workflow'],
                     body: subscription_resource, status: 201)

      subscription_resource['id'] = 'subscription_resource_2'
      create_request(name: 'subscription_create', direction: 'outgoing',
                     tags: ['subscription_creation', 'Full-Resource'], body: subscription_resource, status: 201)

      create_request(name: 'subscription_handshake', direction: 'incoming', tags: ['handshake', subscription_id],
                     body: handshake_bundle)
      result = run(test)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq(
        'Did not receive a handshake notification for some `rest-hook` subscriptions'
      )
      expect(verification_request).to have_been_made.times(1)
    end
  end
end
