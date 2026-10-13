require_relative 'shared_context'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Server::UpdatePutTest, :runnable do
  include_context 'with a created server Subscription'

  it 'skips if no Subscription was created' do
    expect(run(test, url:).result).to eq('skip')
  end

  it 'skips if a Subscription was only created outside of the workflow group' do
    create_subscription_request(tags: ['subscription_creation', 'empty'])

    expect(run(test, url:).result).to eq('skip')
  end

  describe 'when a Subscription was created' do
    before { create_subscription_request }

    it 'passes when the server applies the update and preserves primitive extensions in the request' do
      updated_reason = nil
      request_matcher = lambda do |request|
        body = JSON.parse(request.body)
        updated_reason = body['reason']
        body.dig('channel', '_payload', 'extension').present? && updated_reason.include?('PUT')
      end
      update_request = stub_request(:put, subscription_url)
        .with(&request_matcher)
        .to_return { |request| { status: 200, body: request.body } }
      stub_request(:get, subscription_url)
        .to_return(status: 200, body: subscription.to_json)
        .then.to_return { { status: 200, body: subscription.merge('reason' => updated_reason).to_json } }

      expect(run(test, url:).result).to eq('pass')
      expect(update_request).to have_been_made
    end

    it 'fails when the server does not return a 200' do
      stub_request(:get, subscription_url).to_return(status: 200, body: subscription.to_json)
      stub_request(:put, subscription_url).to_return(status: 405)

      expect(run(test, url:).result).to eq('fail')
    end

    it 'fails when the update is not reflected in a subsequent read' do
      stub_request(:get, subscription_url).to_return(status: 200, body: subscription.to_json)
      stub_request(:put, subscription_url).to_return(status: 200)

      expect(run(test, url:).result).to eq('fail')
    end
  end
end
