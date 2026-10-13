require_relative 'shared_context'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Server::UpdatePatchTest, :runnable do
  include_context 'with a created server Subscription'

  it 'skips if no Subscription was created' do
    expect(run(test, url:).result).to eq('skip')
  end

  describe 'when a Subscription was created' do
    before { create_subscription_request }

    it 'passes when the server applies a JSON Patch' do
      updated_reason = nil
      patch_request = stub_request(:patch, subscription_url)
        .with(headers: { 'Content-Type' => 'application/json-patch+json' }) do |request|
          operation = JSON.parse(request.body).first
          updated_reason = operation['value']
          operation['op'] == 'add' && operation['path'] == '/reason'
        end
        .to_return(status: 200)
      stub_request(:get, subscription_url)
        .to_return(status: 200, body: subscription.to_json)
        .then.to_return { { status: 200, body: subscription.merge('reason' => updated_reason).to_json } }

      expect(run(test, url:).result).to eq('pass')
      expect(patch_request).to have_been_made
    end

    it 'fails when the server does not support JSON Patch' do
      stub_request(:get, subscription_url).to_return(status: 200, body: subscription.to_json)
      stub_request(:patch, subscription_url).to_return(status: 415)

      expect(run(test, url:).result).to eq('fail')
    end
  end
end
