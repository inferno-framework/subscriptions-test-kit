require_relative '../../../../../lib/subscriptions_test_kit/suites/subscriptions_r5_backport_r4_server/' \
                 'common/interaction_verification/notification_conformance_test'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Server::NotificationConformanceTest do
  let(:suite_id) { 'subscriptions_r5_backport_r4_server' }
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

  let(:empty_notification_bundle_non_conformant) do
    JSON.parse(File.read(File.join(
                           __dir__, '../../../..', 'fixtures', 'empty_notification_bundle_non_conformant_example.json'
                         )))
  end

  let(:handshake_bundle) do
    JSON.parse(File.read(File.join(
                           __dir__, '../../../..', 'fixtures', 'handshake_bundle_example.json'
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

  def create_request(url: subscription_channel, direction: 'incoming', tags: nil, body: nil, status: 200, headers: nil,
                     response_body: body)
    headers ||= [
      {
        type: 'request',
        name: 'Authorization',
        value: "Bearer #{access_token}"
      },
      {
        type: 'request',
        name: 'content-type',
        value: 'application/fhir+json'
      }
    ]
    repo_create(
      :request,
      name: 'subscription_notification',
      direction:,
      url:,
      result:,
      test_session_id: test_session.id,
      response_body: response_body.is_a?(Hash) ? response_body.to_json : response_body,
      request_body: body.is_a?(Hash) ? body.to_json : body,
      status:,
      headers:,
      tags:
    )
  end

  describe 'Server Workflow Notification Test' do
    let(:test) do
      Class.new(described_class) do
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
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'full-resource'],
                     body: subscription_resource, status: 201)
      create_request(tags: ['event-notification', subscription_id], body: full_resource_notification_bundle)
      result = run(test)
      expect(result.result).to eq('pass')
      expect(verification_request).to have_been_made
    end

    it 'passes if conformant empty event-notification sent to Subscription channel' do
      verification_request = stub_request(:post, validation_url)
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
      expect(result.result_message).to match(/No successful Subscription creation request/)
    end

    it 'skips if no event-notification requests were made' do
      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'full-resource'],
                     body: subscription_resource, status: 201)
      create_request(tags: ['handshake', subscription_id], body: handshake_bundle)
      result = run(test)
      expect(result.result).to eq('skip')
      expect(result.result_message).to match(/No event-notification requests were made/)
    end

    it 'fails if a non-conformant event-notification is made' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)
      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'full-resource'],
                     body: subscription_resource, status: 201)
      create_request(tags: ['event-notification', subscription_id],
                     body: empty_notification_bundle_non_conformant)
      result = run(test)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/are not conformant/)
      expect(verification_request).to have_been_made.once
    end

    it 'uses the most recent Susbcription if there are multiple' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)
      first_subscription_id = subscription_resource['id']
      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'full-resource'],
                     body: subscription_resource, status: 201)
      create_request(tags: ['event-notification', first_subscription_id],
                     body: full_resource_notification_bundle)

      second_subscription_id = SecureRandom.uuid
      subscription_resource['id'] = second_subscription_id
      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'full-resource'],
                     body: subscription_resource, status: 201)
      create_request(tags: ['event-notification', second_subscription_id],
                     body: empty_notification_bundle_non_conformant)

      result = run(test)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(
        /Received event-notifications for Subscription #{second_subscription_id} are not conformant./
      )
      expect(verification_request).to have_been_made.once
    end

    it 'fails if an expected header is not sent' do
      subscription_resource.dig('channel', 'header') << 'accept: application/fhir+json'
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'empty'],
                     body: subscription_resource, status: 201)
      create_request(tags: ['event-notification', subscription_id], body: empty_notification_bundle)
      result = run(test)
      expect(result.result).to eq('fail')
      expect(verification_request).to have_been_made
    end

    it 'fails if a requested header is not sent and the server response has no header element' do
      subscription_resource.dig('channel', 'header') << 'accept: application/fhir+json'
      response_subscription = subscription_resource.deep_dup
      response_subscription['channel'].delete('header')
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'empty'],
                     body: subscription_resource, response_body: response_subscription, status: 201)
      create_request(tags: ['event-notification', subscription_id], body: empty_notification_bundle)
      result = run(test)
      expect(result.result).to eq('fail')
      messages = Inferno::Repositories::Messages.new.messages_for_result(result.id).map(&:message)
      expect(messages).to include(a_string_including('Requested header not sent: accept: application/fhir+json'))
      expect(verification_request).to have_been_made
    end

    it 'does not check headers the server response adds that Inferno did not request' do
      response_subscription = subscription_resource.deep_dup
      response_subscription.dig('channel', 'header') << 'accept: application/fhir+json'
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'empty'],
                     body: subscription_resource, response_body: response_subscription, status: 201)
      create_request(tags: ['event-notification', subscription_id], body: empty_notification_bundle)
      result = run(test)
      expect(result.result).to eq('pass')
      expect(verification_request).to have_been_made
    end

    it 'passes if the notification sends the requested Authorization header the server response does not match' do
      response_subscription = subscription_resource.deep_dup
      response_subscription['channel']['header'] = ['Authorization: Bearer OTHER_TOKEN']
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'empty'],
                     body: subscription_resource, response_body: response_subscription, status: 201)
      create_request(tags: ['event-notification', subscription_id], body: empty_notification_bundle)
      result = run(test)
      expect(result.result).to eq('pass')
      expect(verification_request).to have_been_made
    end

    it 'fails if the notification sends the Authorization header from the server response, not the requested one' do
      response_subscription = subscription_resource.deep_dup
      response_subscription['channel']['header'] = ['Authorization: Bearer OTHER_TOKEN']
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)
      notification_headers = [
        { type: 'request', name: 'Authorization', value: 'Bearer OTHER_TOKEN' },
        { type: 'request', name: 'content-type', value: 'application/fhir+json' }
      ]

      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'empty'],
                     body: subscription_resource, response_body: response_subscription, status: 201)
      create_request(tags: ['event-notification', subscription_id], body: empty_notification_bundle,
                     headers: notification_headers)
      result = run(test)
      expect(result.result).to eq('fail')
      messages = Inferno::Repositories::Messages.new.messages_for_result(result.id).map(&:message)
      expect(messages).to include(
        a_string_including('Requested value for header authorization does not match the request sent. ' \
                           "Expected Bearer #{access_token}, received Bearer OTHER_TOKEN")
      )
      expect(verification_request).to have_been_made
    end

    it 'fails if the server returned a Subscription body that is not a JSON object' do
      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'empty'],
                     body: subscription_resource, response_body: '[1]', status: 201)
      create_request(tags: ['event-notification', subscription_id], body: empty_notification_bundle)
      result = run(test)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/The Subscription the server returned is not a JSON object/)
    end

    it 'fails if wrong mime type is sent' do
      subscription_resource['channel']['payload'] = 'application/json'
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'empty'],
                     body: subscription_resource, status: 201)
      create_request(tags: ['event-notification', subscription_id], body: empty_notification_bundle)
      result = run(test)
      expect(result.result).to eq('fail')
      expect(verification_request).to have_been_made
    end
  end

  describe 'Server Coverage Full-Resource Notification Test' do
    let(:full_resource_test) do
      Class.new(described_class) do
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
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'full-resource'],
                     body: subscription_resource, status: 201)
      create_request(tags: ['event-notification', subscription_id], body: full_resource_notification_bundle)
      result = run(full_resource_test)
      expect(result.result).to eq('pass')
      expect(verification_request).to have_been_made
    end

    it 'skips if no full-resource Subscription requests were made' do
      create_request(url: server_endpoint, direction: 'outgoing', tags: ['subscription_creation', 'empty'],
                     body: subscription_resource)

      result = run(full_resource_test)
      expect(result.result).to eq('skip')
      expect(result.result_message).to match(/No successful Subscription creation request/)
    end
  end
end
