require_relative '../../../../lib/subscriptions_test_kit/suites/subscriptions_r5_backport_r4_server/' \
                 'capability_statement/topic_discovery_test'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Server::TopicDiscoveryTest do
  let(:suite_id) { 'subscriptions_r5_backport_r4_server' }
  let(:test) { find_test(suite, described_class.id) }
  # let(:test) { Inferno::Repositories::Tests.new.find('subscriptions_r4_server_topic_discovery') }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:capability_statement) do
    JSON.parse(File.read(File.join(
                           __dir__, '../../..', 'fixtures', 'capability_statement_example.json'
                         )))
  end

  let(:subscription_resource) do
    JSON.parse(File.read(File.join(
                           __dir__, '../../..', 'fixtures', 'subscription_resource_example.json'
                         )))
  end

  let(:capability_statement_resource) do
    FHIR.from_contents(capability_statement.to_json)
  end

  let(:server_endpoint) { 'http://example.com/fhir' }
  let(:access_token) { 'SAMPLE_TOKEN' }
  let(:subscription_topic) { 'http://fhirserver.org/topics/patient-admission' }

  def entity_result_message(runnable)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .map(&:message)
      .join(' ')
  end

  def entity_result_message_type(runnable)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .map(&:type)
      .first
  end

  def create_subscription_request(url: server_endpoint, payload_type: 'full-resource', body: nil, status: 201,
                                  headers: nil)
    headers ||= [
      {
        type: 'request',
        name: 'Authorization',
        value: "Bearer #{access_token}"
      }
    ]
    repo_create(
      :request,
      name: 'subscription_create',
      direction: 'outgoing',
      url:,
      result:,
      test_session_id: test_session.id,
      response_body: body.is_a?(Hash) ? body.to_json : body,
      status:,
      headers:,
      tags: ['subscription_creation', payload_type]
    )
  end

  it 'passes if Capability Statement retrieved containing subscription topic extension' do
    result = run(test, { url: server_endpoint }, { capability_statement: capability_statement_resource })
    expect(result.result).to eq('pass')
  end

  it 'skips if no Capability Statement returned in previous test' do
    result = run(test, { url: server_endpoint }, { capability_statement: {} })

    expect(result.result).to eq('skip')
    expect(result.result_message).to eq('No Capability Statement received in previous test')
  end

  it 'fails if Capability Statement does not contain the rest field' do
    capability_statement.delete('rest')

    result = run(test, { url: server_endpoint }, { capability_statement: capability_statement_resource })
    expect(result.result).to eq('fail')
    expect(result.result_message).to eq('Capability Statement missing the `rest` field')
  end

  it 'fails if Capability Statement does not contain entry rest field with mode server' do
    capability_statement['rest'][0]['mode'] = 'client'

    result = run(test, { url: server_endpoint }, { capability_statement: capability_statement_resource })
    expect(result.result).to eq('fail')
    expect(result.result_message).to eq("Capability Statement missing entry in `rest` with a `mode` set to 'server'")
  end

  it 'fails if Capability Statement does not contain the Subscription resource in the rest field' do
    capability_statement['rest'][0]['resource'].shift

    allow_any_instance_of(test)
      .to receive(:scratch_resource)
      .and_return(capability_statement_resource)

    result = run(test, { url: server_endpoint }, { capability_statement: capability_statement_resource })
    expect(result.result).to eq('fail')
    expect(result.result_message).to eq('Capability Statement missing `Subscription` resource in `rest` field')
  end

  it 'fails if Subscription in Capability Statement does not contain the extension field' do
    capability_statement['rest'][0]['resource'][0].delete('extension')

    result = run(test, { url: server_endpoint }, { capability_statement: capability_statement_resource })
    expect(result.result).to eq('fail')
    expect(result.result_message).to eq(
      'Capability Statement missing the `extension` field on the Subscription resource'
    )
  end

  it 'fails if Subscription does not contain the subscriptiontopic extension in the extension field' do
    capability_statement['rest'][0]['resource'][0]['extension'].shift
    capability_statement['rest'][0]['resource'][0]['extension'][0]['url'] = 'incorrect_extension'

    result = run(test, { url: server_endpoint }, { capability_statement: capability_statement_resource })
    expect(result.result).to eq('fail')
    expect(result.result_message).to match(
      'The server SHOULD support topic discovery via the CapabilityStatement SubscriptionTopic Canonical'
    )
  end

  it 'provides warning if no Subscription requests made prior to this test' do
    result = run(test, { url: server_endpoint }, { capability_statement: capability_statement_resource })
    expect(result.result).to eq('pass')
    expect(entity_result_message(test)).to match('No Subscription requests have been made in previous tests.')
    expect(entity_result_message_type(test)).to eq('warning')
  end

  it 'provides warning if no Subscriptions contain topics in the criteria field' do
    subscription_resource.delete('criteria')
    create_subscription_request(body: subscription_resource)

    result = run(test, { url: server_endpoint }, { capability_statement: capability_statement_resource })
    expect(result.result).to eq('pass')
    expect(entity_result_message(test)).to match(
      'Subscriptions missing criteria field containing a Subscription topic URL. Could not verify any'
    )
    expect(entity_result_message_type(test)).to eq('warning')
  end

  it 'passes if Subscription request made and contains criteria found in subscription topic extension' do
    create_subscription_request(body: subscription_resource)

    result = run(test, { url: server_endpoint }, { capability_statement: capability_statement_resource })
    expect(result.result).to eq('pass')
  end

  it 'fails if Subscription request made and contains criteria not found in subscription topic extension' do
    subscription_resource['criteria'] = 'unsupported_topic'
    create_subscription_request(body: subscription_resource)

    result = run(test, { url: server_endpoint }, { capability_statement: capability_statement_resource })
    expect(result.result).to eq('fail')
    expect(result.result_message).to eq(
      "Subscription.criteria value(s) not found in Capability Statement's SubscriptionTopic Canonical extension"
    )
    expect(entity_result_message(test)).to match(
      'The SubscriptionTopic Canonical extension should include the Subscription Topic URLs found'
    )
  end
end
