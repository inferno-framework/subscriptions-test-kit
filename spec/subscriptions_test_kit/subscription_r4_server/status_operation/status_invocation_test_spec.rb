require_relative '../../../../lib/subscriptions_test_kit/suites/subscriptions_r5_backport_r4_server/' \
                 'status_operation/status_invocation_test'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Server::StatusInvocationTest do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('subscriptions_r5_backport_r4_server') }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'subscriptions_r5_backport_r4_server') }
  let(:result) { repo_create(:result, test_session_id: test_session.id) }

  let(:subscription_status) do
    JSON.parse(File.read(File.join(
                           __dir__, '../../..', 'fixtures', 'subscription_status_example.json'
                         )))
  end

  let(:subscription_resource) do
    JSON.parse(File.read(File.join(
                           __dir__, '../../..', 'fixtures', 'subscription_resource_example.json'
                         )))
  end

  let(:operation_outcome_success) do
    {
      outcomes: [{
        issues: []
      }],
      sessionId: 'b8cf5547-1dc7-4714-a797-dc2347b93fe2'
    }
  end

  let(:operation_outcome_failure) do
    {
      outcomes: [{
        issues: [{
          level: 'ERROR',
          message: 'Resource does not conform to profile'
        }]
      }],
      sessionId: 'b8cf5547-1dc7-4714-a797-dc2347b93fe2'
    }
  end

  let(:server_endpoint) { 'http://example.com/fhir' }
  let(:access_token) { 'SAMPLE_TOKEN' }
  let(:validator_url) { ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL') }

  def entity_result_message(runnable)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .map(&:message)
      .join(' ')
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

  describe 'Server Coverage Subscription Status' do
    let(:test) do
      Class.new(SubscriptionsTestKit::SubscriptionsR5BackportR4Server::StatusInvocationTest) do
        fhir_resource_validator do
          url ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL')

          cli_context do
            txServer nil
            displayWarnings true
            disableDefaultResourceFetcher true
          end

          igs('hl7.fhir.uv.subscriptions-backport#1.1.0')
        end

        fhir_client do
          url :server_endpoint
          oauth_credentials :server_credentials
        end

        input :server_endpoint
        input :server_credentials, type: :oauth_credentials
      end
    end

    it 'passes if Conformant Subscription status response returned from $status operation' do
      allow(test).to receive(:suite).and_return(suite)

      verification_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)
      status_operation = stub_request(:get, "#{server_endpoint}/Subscription/123/$status")
        .to_return(status: 200, body: subscription_status.to_json)

      create_subscription_request(body: subscription_resource)
      result = run(test, server_endpoint:)

      expect(result.result).to eq('pass')
      expect(verification_request).to have_been_made.times(2)
      expect(status_operation).to have_been_made
    end

    it 'skips if no conformant Subscription requests were made' do
      allow(test).to receive(:suite).and_return(suite)

      result = run(test, server_endpoint:)
      expect(result.result).to eq('skip')
      expect(result.result_message).to match(
        'No successful Subscription creation requests were made in previous tests. Must run Subscription Workflow tests'
      )
    end

    it 'fails if Subscription status operation returns a non 200' do
      allow(test).to receive(:suite).and_return(suite)

      status_operation = stub_request(:get, "#{server_endpoint}/Subscription/123/$status")
        .to_return(status: 404, body: subscription_status.to_json)

      create_subscription_request(body: subscription_resource)

      result = run(test, server_endpoint:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected response status: expected 200, but received 404')
      expect(status_operation).to have_been_made
    end

    it 'fails if Subscription status operation does not return a Bundle' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_status['resourceType'] = 'Patient'
      status_operation = stub_request(:get, "#{server_endpoint}/Subscription/123/$status")
        .to_return(status: 200, body: subscription_status.to_json)

      create_subscription_request(body: subscription_resource)

      result = run(test, server_endpoint:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected resource type: expected Bundle, but received Patient')
      expect(status_operation).to have_been_made
    end

    it 'fails if Subscription status operation does not return a valid Bundle' do
      allow(test).to receive(:suite).and_return(suite)

      verification_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_failure.to_json)
      status_operation = stub_request(:get, "#{server_endpoint}/Subscription/123/$status")
        .to_return(status: 200, body: subscription_status.to_json)

      create_subscription_request(body: subscription_resource)

      result = run(test, server_endpoint:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Resource does not conform to the base Bundle profile.')
      expect(verification_request).to have_been_made
      expect(status_operation).to have_been_made
    end

    it 'fails if Subscription status Bundle is not type `searchset`' do
      allow(test).to receive(:suite).and_return(suite)

      subscription_status['type'] = 'history'
      verification_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)
      status_operation = stub_request(:get, "#{server_endpoint}/Subscription/123/$status")
        .to_return(status: 200, body: subscription_status.to_json)

      create_subscription_request(body: subscription_resource)

      result = run(test, server_endpoint:)

      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to eq(
        "Bundle returned from $status operation should be type 'searchset', was history"
      )
      expect(verification_request).to have_been_made.times(2)
      expect(status_operation).to have_been_made
    end

    it 'fails if Subscription status Bundle does not contain a subscription parameter with correct reference id' do
      allow(test).to receive(:suite).and_return(suite)

      verification_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json)
      status_operation = stub_request(:get, "#{server_endpoint}/Subscription/wrong_id/$status")
        .to_return(status: 200, body: subscription_status.to_json)

      subscription_resource['id'] = 'wrong_id'
      create_subscription_request(body: subscription_resource)

      result = run(test, server_endpoint:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(
        'No Subscription status with id wrong_id returned from $status operation'
      )
      expect(verification_request).to have_been_made
      expect(status_operation).to have_been_made
    end

    it 'fails if Parameter resource in Subscription Status Bundle is not conformant' do
      allow(test).to receive(:suite).and_return(suite)

      verification_request = stub_request(:post, "#{validator_url}/validate")
        .to_return(status: 200, body: operation_outcome_success.to_json).then
        .to_return(status: 200, body: operation_outcome_failure.to_json)
      status_operation = stub_request(:get, "#{server_endpoint}/Subscription/123/$status")
        .to_return(status: 200, body: subscription_status.to_json)

      create_subscription_request(body: subscription_resource)

      result = run(test, server_endpoint:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(
        'Resource does not conform to the profile: http://hl7.org/fhir/uv/subscriptions-backport/'
      )
      expect(verification_request).to have_been_made.times(2)
      expect(status_operation).to have_been_made
    end
  end
end
