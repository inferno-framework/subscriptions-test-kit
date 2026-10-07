require_relative 'shared_context'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Server::DeleteTest, :runnable do
  include_context 'with a created server Subscription'

  it 'skips if no Subscription was created' do
    expect(run(test, url:).result).to eq('skip')
  end

  describe 'when a Subscription was created' do
    before { create_subscription_request }

    it 'passes when the Subscription is deleted' do
      delete_request = stub_request(:delete, subscription_url).to_return(status: 204)
      read_request = stub_request(:get, subscription_url).to_return(status: 410)

      expect(run(test, url:).result).to eq('pass')
      expect(delete_request).to have_been_made
      expect(read_request).to have_been_made
    end

    it 'passes without a read when the server accepts the deletion for later processing' do
      stub_request(:delete, subscription_url).to_return(status: 202)
      read_request = stub_request(:get, subscription_url)

      expect(run(test, url:).result).to eq('pass')
      expect(read_request).to_not have_been_made
    end

    it 'fails when the server rejects the deletion' do
      stub_request(:delete, subscription_url).to_return(status: 405)

      expect(run(test, url:).result).to eq('fail')
    end

    it 'fails when the Subscription can still be read after deletion' do
      stub_request(:delete, subscription_url).to_return(status: 200)
      stub_request(:get, subscription_url).to_return(status: 200, body: subscription.to_json)

      expect(run(test, url:).result).to eq('fail')
    end
  end
end
