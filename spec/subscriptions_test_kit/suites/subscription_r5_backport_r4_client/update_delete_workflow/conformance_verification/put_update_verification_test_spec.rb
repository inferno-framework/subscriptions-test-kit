require_relative 'update_verification_context'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Client::PutUpdateVerificationTest, :runnable do
  include_context 'with client Subscription update requests'

  it 'skips when no Subscription was created' do
    expect(run(test).result).to eq('skip')
  end

  it 'skips when the created Subscription was not updated' do
    create_subscription
    expect(run(test).result).to eq('skip')
  end

  it 'skips when only a different Subscription id was updated' do
    create_subscription
    put_subscription(subscription.merge('id' => 'other'), id: 'other')
    expect(run(test).result).to eq('skip')
  end

  it 'skips when the Subscription was only updated using PATCH' do
    create_subscription
    patch_subscription(status: 200, response_body: subscription)

    result = run(test)
    expect(result.result).to eq('skip')
    expect(result.result_message).to match(/did not receive a PUT request/)
  end

  it 'passes when the PUT update is conformant' do
    validation_request = stub_request(:post, validation_url)
      .to_return(status: 200, body: validation_success.to_json)
    create_subscription
    put_subscription(subscription)

    expect(run(test).result).to eq('pass')
    expect(validation_request).to have_been_made
  end

  it 'fails when Inferno rejected the PUT update' do
    create_subscription
    put_subscription(subscription.merge('id' => 'other'), status: 400,
                                                          response_body: error_outcome('id does not match'))

    expect(run(test).result).to eq('fail')
    expect(entity_result_message).to match(/status 400.*id does not match/m)
  end

  it 'ignores PUT updates to a different Subscription id' do
    stub_request(:post, validation_url).to_return(status: 200, body: validation_success.to_json)
    create_subscription
    put_subscription(subscription.merge('id' => 'other'), id: 'other')
    put_subscription(subscription)

    expect(run(test).result).to eq('pass')
    expect(entity_result_message).to be_empty
  end

  it 'fails when any PUT update is not conformant, identifying the request' do
    stub_request(:post, validation_url).to_return(status: 200, body: validation_success.to_json)
    create_subscription
    put_subscription(subscription)
    put_subscription(subscription.merge('id' => 'other'), status: 400,
                                                          response_body: error_outcome('id does not match'))

    expect(run(test).result).to eq('fail')
    expect(entity_result_message).to match(/Request 2: .*status 400.*id does not match/m)
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
