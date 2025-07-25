require_relative '../../../../../lib/subscriptions_test_kit/suites/subscriptions_r5_backport_r4_server/' \
                 'common/interaction/notification_delivery_test'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Server::NotificationDeliveryTest, :request do
  let(:suite_id) { 'subscriptions_r5_backport_r4_server' }
  let(:test) { find_test suite, described_class.id }
  let(:test_group) { test.parent }
  let(:results_repo) { Inferno::Repositories::Results.new }

  let(:handshake_bundle) do
    JSON.parse(File.read(File.join(
                           __dir__, '../../../..', 'fixtures', 'handshake_bundle_example.json'
                         )))
  end

  let(:heartbeat_bundle) do
    JSON.parse(File.read(File.join(
                           __dir__, '../../../..', 'fixtures', 'heartbeat_bundle_example.json'
                         )))
  end

  let(:notification_bundle) do
    JSON.parse(File.read(File.join(
                           __dir__, '../../../..', 'fixtures', 'full_resource_notification_bundle_example.json'
                         )))
  end

  let(:subscription_channel) do
    "#{Inferno::Application['base_url']}/custom/subscriptions_r5_backport_r4_server/subscription/channel/" \
      'notification_listener'
  end

  let(:subscription_resource) do
    JSON.parse(File.read(File.join(
                           __dir__, '../../../..', 'fixtures', 'subscription_resource_example.json'
                         )))
  end

  let(:access_token) { 'SAMPLE_TOKEN' }
  let(:server_endpoint) { 'http://example.com/fhir' }
  let(:server_credentials) do
    {
      access_token: 'SAMPLE_TOKEN',
      refresh_token: 'REFRESH_TOKEN',
      expires_in: 3600,
      client_id: 'CLIENT_ID',
      issue_time: Time.now.iso8601,
      token_url: 'http://example.com/token'
    }.to_json
  end

  let(:resume_pass_url) do
    "#{Inferno::Application['base_url']}/custom/subscriptions_r5_backport_r4_server/resume_pass?token=" \
      "notification%20#{access_token}"
  end

  def post_fhir(path, data)
    post path, data.to_json, 'CONTENT_TYPE' => 'application/fhir+json'
  end

  describe 'Server Receive Notification Test' do
    let(:test) do
      Class.new(SubscriptionsTestKit::SubscriptionsR5BackportR4Server::NotificationDeliveryTest) do
        fhir_client do
          url :server_endpoint
          auth_info :server_credentials
        end

        input :server_endpoint
        input :server_credentials, type: :auth_info
      end
    end

    it 'passes if Subscription creation returns 201 and Notification has correct Bearer token and type parameter' do
      allow(test).to receive_messages(suite:, parent: test_group)

      subscription_creation_request = stub_request(:post, "#{server_endpoint}/Subscription")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 201, body: subscription_resource.to_json)

      result = run(test, updated_subscription: subscription_resource.to_json, access_token:, server_endpoint:,
                         server_credentials:)

      expect(result.result).to eq('wait')

      header('Authorization', "Bearer #{access_token}")
      post_fhir(subscription_channel, handshake_bundle)
      post_fhir(subscription_channel, heartbeat_bundle)
      post_fhir(subscription_channel, notification_bundle)
      expect(last_response).to be_ok

      get(resume_pass_url)

      result = results_repo.find(result.id)
      expect(result.result).to eq('pass')
      expect(subscription_creation_request).to have_been_made
    end

    it 'fails if Subscription creation returns non 201' do
      allow(test).to receive_messages(suite:, parent: test_group)

      subscription_creation_request = stub_request(:post, "#{server_endpoint}/Subscription")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 404, body: subscription_resource.to_json)

      result = run(test, updated_subscription: subscription_resource.to_json, access_token:, server_endpoint:,
                         server_credentials:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected response status: expected 201, but received 404')
      expect(subscription_creation_request).to have_been_made
    end

    it 'Responds 500 if request sent to the provided URL does not have correct Bearer token' do
      allow(test).to receive_messages(suite:, parent: test_group)

      subscription_creation_request = stub_request(:post, "#{server_endpoint}/Subscription")
        .with(
          headers: { Authorization: 'Bearer SAMPLE_TOKEN' }
        )
        .to_return(status: 201, body: subscription_resource.to_json)

      result = run(test, updated_subscription: subscription_resource.to_json, access_token:, server_endpoint:,
                         server_credentials:)

      expect(result.result).to eq('wait')

      access_token = 'WRONG_TOKEN'
      header('Authorization', "Bearer #{access_token}")
      post_json(subscription_channel, handshake_bundle)
      post_json(subscription_channel, heartbeat_bundle)
      post_json(subscription_channel, notification_bundle)
      expect(last_response).to be_server_error
      expect(last_response.body).to eq("Unable to find test run with identifier 'notification WRONG_TOKEN'.")

      get(resume_pass_url)

      result = results_repo.find(result.id)
      expect(result.result).to eq('pass')
      expect(subscription_creation_request).to have_been_made
    end
  end
end
