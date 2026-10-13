require_relative 'update_verification_context'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Client::PutUpdateVerificationTest, :runnable do
  include_context 'with client Subscription update requests'

  it 'skips when no Subscription was created' do
    expect(run(test).result).to eq('skip')
  end

  it 'skips when the created Subscription was not updated' do
    create_subscription
    put_subscription(subscription.merge('id' => 'other'), id: 'other')
    expect(run(test).result).to eq('skip')
  end

  it 'omits when the Subscription was only updated using PATCH' do
    create_subscription
    patch_subscription(status: 200, response_body: subscription)
    expect(run(test).result).to eq('omit')
  end

  it 'passes when the PUT update is conformant' do
    validation_request = stub_request(:post, validation_url)
      .to_return(status: 200, body: validation_success.to_json)
    create_subscription
    put_subscription(subscription)

    expect(run(test).result).to eq('pass')
    expect(validation_request).to have_been_made
  end

  it 'fails when the id in the PUT body does not match the url' do
    stub_request(:post, validation_url).to_return(status: 200, body: validation_success.to_json)
    create_subscription
    put_subscription(subscription.merge('id' => 'other'))

    expect(run(test).result).to eq('fail')
  end

  {
    'not a JSON object' => [],
    'null' => nil,
    'missing a channel' => { 'resourceType' => 'Subscription', 'id' => 'abc-123' }
  }.each do |description, body|
    it "fails when the PUT body is #{description}" do
      create_subscription
      put_subscription(body)

      expect(run(test).result).to eq('fail')
    end
  end
end
