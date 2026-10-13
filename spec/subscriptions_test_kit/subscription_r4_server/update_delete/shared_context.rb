RSpec.shared_context('with a created server Subscription') do
  let(:suite_id) { 'subscriptions_r5_backport_r4_server' }
  let(:test) { find_test suite, described_class.id }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }
  let(:url) { 'http://example.com/fhir' }
  let(:subscription_url) { "#{url}/Subscription/123" }
  let(:subscription) do
    JSON.parse(File.read(File.join(__dir__, '../../..', 'fixtures', 'subscription_resource_example.json')))
  end

  def create_subscription_request(tags: ['subscription_creation', 'workflow'])
    repo_create(:request, direction: 'outgoing', url: "#{url}/Subscription", result:,
                          test_session_id: test_session.id, status: 201, response_body: subscription.to_json,
                          tags:)
  end
end
