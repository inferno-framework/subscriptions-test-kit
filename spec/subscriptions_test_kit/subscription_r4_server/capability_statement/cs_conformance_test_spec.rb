require_relative '../../../../lib/subscriptions_test_kit/suites/subscriptions_r5_backport_r4_server/' \
                 'capability_statement/cs_conformance_test'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Server::CSConformanceTest do
  let(:suite_id) { 'subscriptions_r5_backport_r4_server' }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:capability_statement) do
    JSON.parse(File.read(File.join(
                           __dir__, '../../../', 'fixtures', 'capability_statement_example.json'
                         )))
  end

  let(:operation_outcome_success) do
    {
      outcomes: [{
        issues: []
      }],
      sessionId: test_session.id
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
      sessionId: test_session.id
    }
  end

  let(:server_endpoint) { 'http://example.com/fhir' }

  def entity_result_message(runnable)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .map(&:message)
      .join(' ')
  end

  describe 'Server Coverage Topic Discovery' do
    let(:test) do
      Class.new(SubscriptionsTestKit::SubscriptionsR5BackportR4Server::CSConformanceTest) do
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
        end

        input :server_endpoint
      end
    end

    it 'passes if Capability Statement retrieved containing subscription topic extension' do
      allow(test).to receive(:suite).and_return(suite)

      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)
      get_capability_statement = stub_request(:get, "#{server_endpoint}/metadata")
        .to_return(status: 200, body: capability_statement.to_json)

      result = run(test, server_endpoint:)
      expect(result.result).to eq('pass')

      expect(verification_request).to have_been_made
      expect(get_capability_statement).to have_been_made
    end

    it 'fails if Capability Statement retrieval returns non 200' do
      allow(test).to receive(:suite).and_return(suite)

      get_capability_statement = stub_request(:get, "#{server_endpoint}/metadata")
        .to_return(status: 404, body: capability_statement.to_json)

      result = run(test, server_endpoint:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected response status: expected 200, but received 404')
      expect(get_capability_statement).to have_been_made.times(7)
    end

    it 'fails if Capability Statement returned is not conformant' do
      allow(test).to receive(:suite).and_return(suite)

      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_failure.to_json)
      get_capability_statement = stub_request(:get, "#{server_endpoint}/metadata")
        .to_return(status: 200, body: capability_statement.to_json)

      result = run(test, server_endpoint:)

      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Resource does not conform to the base CapabilityStatement profile.')
      expect(verification_request).to have_been_made
      expect(get_capability_statement).to have_been_made
    end

    it 'fails if Capability Statement does not contain the rest field' do
      allow(test).to receive(:suite).and_return(suite)

      capability_statement.delete('rest')

      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)
      get_capability_statement = stub_request(:get, "#{server_endpoint}/metadata")
        .to_return(status: 200, body: capability_statement.to_json)

      result = run(test, server_endpoint:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Capability Statement missing the `rest` field')
      expect(verification_request).to have_been_made
      expect(get_capability_statement).to have_been_made
    end

    it 'fails if Capability Statement does not contain entry rest field with mode server' do
      allow(test).to receive(:suite).and_return(suite)

      capability_statement['rest'][0]['mode'] = 'client'

      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)
      get_capability_statement = stub_request(:get, "#{server_endpoint}/metadata")
        .to_return(status: 200, body: capability_statement.to_json)

      result = run(test, server_endpoint:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq("Capability Statement missing entry in `rest` with a `mode` set to 'server'")
      expect(verification_request).to have_been_made
      expect(get_capability_statement).to have_been_made
    end

    it 'fails if Capability Statement does not contain the Subscription resource in the rest field' do
      allow(test).to receive(:suite).and_return(suite)

      capability_statement['rest'][0]['resource'].shift
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)
      get_capability_statement = stub_request(:get, "#{server_endpoint}/metadata")
        .to_return(status: 200, body: capability_statement.to_json)

      result = run(test, server_endpoint:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Capability Statement missing `Subscription` resource in `rest` field')
      expect(verification_request).to have_been_made
      expect(get_capability_statement).to have_been_made
    end

    it 'fails if Subscription in Capability Statement does not contain the supportedProfile field' do
      allow(test).to receive(:suite).and_return(suite)

      capability_statement['rest'][0]['resource'][0].delete('supportedProfile')

      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)
      get_capability_statement = stub_request(:get, "#{server_endpoint}/metadata")
        .to_return(status: 200, body: capability_statement.to_json)

      result = run(test, server_endpoint:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq(
        'Capability Statement missing the `supportedProfile` field in `Subscription` resource'
      )
      expect(verification_request).to have_been_made
      expect(get_capability_statement).to have_been_made
    end

    it 'warns if Subscription does not contain the backport-subscription extension in the supportedProfile field' do
      allow(test).to receive(:suite).and_return(suite)

      capability_statement['rest'][0]['resource'][0]['supportedProfile'] = 'incorrect_profile'
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)
      get_capability_statement = stub_request(:get, "#{server_endpoint}/metadata")
        .to_return(status: 200, body: capability_statement.to_json)

      result = run(test, server_endpoint:)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(
        'Subscription resource should declare support for the Backport Subscription Profile by including'
      )
      expect(verification_request).to have_been_made
      expect(get_capability_statement).to have_been_made
    end
  end
end
