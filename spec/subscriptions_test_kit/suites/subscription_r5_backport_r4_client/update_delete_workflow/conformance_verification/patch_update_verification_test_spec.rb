require_relative 'update_verification_context'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Client::PatchUpdateVerificationTest, :runnable do
  include_context 'with client Subscription update requests'

  it 'skips when no Subscription was created' do
    expect(run(test).result).to eq('skip')
  end

  it 'skips when the created Subscription was not updated' do
    create_subscription
    expect(run(test).result).to eq('skip')
  end

  it 'omits when the Subscription was only updated using PUT' do
    create_subscription
    put_subscription(subscription)
    expect(run(test).result).to eq('omit')
  end

  it 'passes when a JSON Patch results in a conformant Subscription' do
    validation_request = stub_request(:post, validation_url)
      .to_return(status: 200, body: validation_success.to_json)
    create_subscription
    patch_subscription(status: 200, response_body: subscription.merge('reason' => 'patched'))

    expect(run(test).result).to eq('pass')
    expect(validation_request).to have_been_made
  end

  it 'skips when only a different Subscription id was patched' do
    create_subscription
    patch_subscription(status: 404, response_body: error_outcome('not found'), id: 'other')
    expect(run(test).result).to eq('skip')
  end

  it 'fails when any patch is not conformant, identifying the request' do
    stub_request(:post, validation_url).to_return(status: 200, body: validation_success.to_json)
    create_subscription
    patch_subscription(status: 200, response_body: subscription.merge('reason' => 'patched'))
    patch_subscription(status: 422, response_body: error_outcome('Unable to apply'))

    expect(run(test).result).to eq('fail')
    expect(entity_result_message).to match(/Request 2: .*Unable to apply/m)
  end

  it 'fails when Inferno could not apply a patch' do
    create_subscription
    patch_subscription(status: 422, response_body: {
                         resourceType: 'OperationOutcome',
                         issue: [{ severity: 'error', code: 'processing', details: { text: 'Unable to apply' } }]
                       })

    expect(run(test).result).to eq('fail')
  end
end
