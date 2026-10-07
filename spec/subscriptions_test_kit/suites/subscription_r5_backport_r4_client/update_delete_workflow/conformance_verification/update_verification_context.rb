RSpec.shared_context('with client Subscription update requests') do
  let(:suite_id) { 'subscriptions_r5_backport_r4_client' }
  let(:test) { find_test suite, described_class.id }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:subscription_id) { 'abc-123' }
  let(:subscription_base_url) { "http://example.com/custom/#{suite_id}/fhir/Subscription" }
  let(:subscription) do
    JSON.parse(File.read(File.join(__dir__, '../../../../..', 'fixtures', 'subscription_resource_example.json')))
      .merge('id' => subscription_id)
  end
  let(:validation_success) { { outcomes: [{ issues: [] }], sessionId: test_session.id } }

  def create_request(verb:, url:, status:, tags:, request_body: nil, response_body: nil)
    repo_create(:request, verb:, url:, direction: 'incoming', status:, request_body:, response_body:,
                          result:, test_session_id: test_session.id, tags:)
  end

  def create_subscription
    create_request(verb: 'POST', url: subscription_base_url, status: 201,
                   tags: [SubscriptionsTestKit::SUBSCRIPTION_CREATE_TAG], response_body: subscription.to_json)
  end

  def put_subscription(body, id: subscription_id)
    create_request(verb: 'PUT', url: "#{subscription_base_url}/#{id}", status: 200,
                   tags: [SubscriptionsTestKit::SUBSCRIPTION_UPDATE_TAG, id], request_body: body.to_json)
  end

  def patch_subscription(status:, response_body:)
    create_request(verb: 'PATCH', url: "#{subscription_base_url}/#{subscription_id}", status:,
                   tags: [SubscriptionsTestKit::SUBSCRIPTION_UPDATE_TAG, subscription_id],
                   request_body: [{ op: 'replace', path: '/reason', value: 'patched' }].to_json,
                   response_body: response_body.to_json)
  end
end
