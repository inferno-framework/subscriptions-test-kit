require_relative '../../../../../lib/subscriptions_test_kit/suites/subscriptions_r5_backport_r4_server/' \
                 'common/interaction/creation_response_conformance_test'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Server::CreationResponseConformanceTest do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('subscriptions_r5_backport_r4_server') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'subscriptions_r5_backport_r4_server') }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:subscription_resource) do
    JSON.parse(File.read(File.join(
                           __dir__, '../../../..', 'fixtures', 'subscription_resource_example.json'
                         )))
  end

  let(:server_endpoint) { 'http://example.com/fhir/Subscription' }
  let(:access_token) { 'SAMPLE_TOKEN' }

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

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(
        test_session_id: test_session.id,
        name:,
        value:,
        type: runnable.config.input_type(name) || 'text'
      )
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  describe 'Server Workflow Subscription Response Test' do
    let(:test) do
      Class.new(described_class)
    end

    it 'passes if conformant Subscription for full-resource Notification passed in' do
      allow(test).to receive(:suite).and_return(suite)

      create_subscription_request(body: subscription_resource)

      result = run(test)
      expect(result.result).to eq('pass')
    end

    it 'passes if conformant Subscription for empty Notification passed in' do
      allow(test).to receive(:suite).and_return(suite)

      create_subscription_request(body: subscription_resource, payload_type: 'empty')

      result = run(test)
      expect(result.result).to eq('pass')
    end

    it 'fails if subscription is not valid json' do
      allow(test).to receive(:suite).and_return(suite)

      create_subscription_request(body: '[[')

      result = run(test)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Invalid JSON. ')
    end

    it 'fails if subscription creation request does not return a Subscription resource' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['resourceType'] = 'Patient'
      create_subscription_request(body: subscription_resource)

      result = run(test)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected resource type: expected Subscription, but received Patient')
    end

    it 'fails if subscription creation request returns a Subscription resource with incorrect status' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_resource['status'] = 'active'
      create_subscription_request(body: subscription_resource)

      result = run(test)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/The Subscription resource should have it's status set to 'requested'/)
    end
  end

  describe 'Server Coverage Full-Resource Subscription Response Test' do
    let(:test) do
      Class.new(SubscriptionsTestKit::SubscriptionsR5BackportR4Server::CreationResponseConformanceTest) do
        config(
          options: { subscription_type: 'full-resource' }
        )
      end
    end

    it 'passes if conformant full-resource Subscriptions passed in' do
      allow(test).to receive(:suite).and_return(suite)

      create_subscription_request(body: subscription_resource)
      create_subscription_request(body: subscription_resource)

      result = run(test)

      expect(result.result).to eq('pass')
    end

    it 'skips if no full-resource Subscriptions passed in' do
      allow(test).to receive(:suite).and_return(suite)

      create_subscription_request(body: subscription_resource, payload_type: 'empty')

      result = run(test)

      expect(result.result).to eq('skip')
      expect(result.result_message).to eq('No successful Subscription creation request was made in the previous test.')
    end
  end
end
