RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Client::DeleteVerificationTest, :runnable do
  let(:suite_id) { 'subscriptions_r5_backport_r4_client' }
  let(:test) { find_test suite, described_class.id }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:subscription_id) { 'abc-123' }
  let(:subscription_base_url) { "http://example.com/custom/#{suite_id}/fhir/Subscription" }

  def create_request(verb:, url:, status:, tags:, response_body: nil)
    repo_create(:request, verb:, url:, direction: 'incoming', status:, response_body:,
                          result:, test_session_id: test_session.id, tags:)
  end

  def create_subscription
    create_request(verb: 'POST', url: subscription_base_url, status: 201,
                   tags: [SubscriptionsTestKit::SUBSCRIPTION_CREATE_TAG],
                   response_body: { resourceType: 'Subscription', id: subscription_id }.to_json)
  end

  def delete_subscription(id: subscription_id, status: 204)
    create_request(verb: 'DELETE', url: "#{subscription_base_url}/#{id}", status:,
                   tags: [SubscriptionsTestKit::SUBSCRIPTION_DELETE_TAG, id])
  end

  it 'skips when no Subscription was created' do
    expect(run(test).result).to eq('skip')
  end

  it 'skips when no delete request was received' do
    create_subscription
    expect(run(test).result).to eq('skip')
  end

  it 'passes when the created Subscription is deleted' do
    create_subscription
    delete_subscription

    expect(run(test).result).to eq('pass')
  end

  it 'fails when the delete request does not target the created Subscription' do
    create_subscription
    delete_subscription(id: 'other', status: 404)

    expect(run(test).result).to eq('fail')
  end
end
