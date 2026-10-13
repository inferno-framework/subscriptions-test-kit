RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Client::InteractionTest, :request do
  let(:suite_id) { 'subscriptions_r5_backport_r4_client' }

  describe 'performing interactions with the client under test' do
    let(:access_token) { '1234' }

    # Pattern for execution with tester inputs
    # 1. get the runnable into the `test` variable
    # 2. create input hash, e.g., inputs = { ... }
    # 3. pass to the run method (defined in the shared context), e.g., result = run(test, inputs)
    let(:test) { find_test suite, described_class.id }

    describe 'when the tester-provided notification bundle is valid' do
      let(:valid_notification_json) do
        File.read(File.join(__dir__, '../../../..', 'fixtures', 'empty_notification_bundle_example.json'))
      end
      let(:resume_pass_url) { "/custom/#{suite_id}/resume_pass" }
      let(:resume_fail_url) { "/custom/#{suite_id}/resume_fail" }
      let(:results_repo) { Inferno::Repositories::Results.new }

      # Pattern for wait testing
      # 1. execute the test, e.g., result = run(test, ...)
      # 2. verify the test is waiting, e.g., expect(result.result).to eq('wait')
      # 3. perform an action that cause the wait to end, e.g., get(...)
      # 4. find the updated result, e.g., result = results_repo.find(result.id)
      # 5. verify it is no longer waiting, e.g., expect(result.result).to eq('pass')
      it 'passes when the tester chooses to complete the tests' do
        inputs = { access_token:, notification_bundle: valid_notification_json }
        result = run(test, inputs)
        expect(result.result).to eq('wait')

        get("#{resume_pass_url}?test_run_identifier=#{access_token}")

        result = results_repo.find(result.id)
        expect(result.result).to eq('pass')
      end

      describe 'when the client creates a Subscription' do
        let(:subscription_path) { "/custom/#{suite_id}/fhir/Subscription" }
        let(:subscription) do
          subscription = JSON.parse(File.read(File.join(__dir__, '../../../..', 'fixtures',
                                                        'subscription_resource_example.json')))
          # Inferno does not support heartbeats
          subscription['channel']['extension'].reject! { |e| e['url'].end_with?('backport-heartbeat-period') }
          subscription
        end

        before do
          run(test, access_token:, notification_bundle: valid_notification_json)
          header 'Authorization', "Bearer #{access_token}"
        end

        it 'rejects a request body that is not a Subscription' do
          post(subscription_path, 'not json')
          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body).dig('issue', 0, 'code')).to eq('invalid')
        end

        it 'rejects a second Subscription' do
          repo_create(:request, verb: 'POST', url: "http://example.com#{subscription_path}", direction: 'incoming',
                                status: 201, response_body: subscription.merge('id' => 'abc-123').to_json,
                                result: repo_create(:result, test_session_id: test_session.id),
                                test_session_id: test_session.id,
                                tags: [SubscriptionsTestKit::SUBSCRIPTION_CREATE_TAG])

          post(subscription_path, subscription.to_json)
          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body).dig('issue', 0, 'code')).to eq('business-rule')
        end
      end

      it 'fails when the tester chooses to fail the tests' do
        inputs = { access_token:, notification_bundle: valid_notification_json }
        result = run(test, inputs)
        expect(result.result).to eq('wait')

        get("#{resume_fail_url}?test_run_identifier=#{access_token}")

        result = results_repo.find(result.id)
        expect(result.result).to eq('fail')
      end
    end

    describe 'when the tester-provided notification bundle is not valid' do
      it 'fails when the notification bundle is not json' do
        inputs = { access_token:, notification_bundle: 'not json' }
        result = run(test, inputs)
        expect(result.result).to eq('fail')
      end

      it 'fails when the notification bundle is not FHIR' do
        inputs = { access_token:, notification_bundle: '{"not":"FHIR"}' }
        result = run(test, inputs)
        expect(result.result).to eq('fail')
      end

      it 'fails when the notification bundle is not a Bundle' do
        inputs = { access_token:, notification_bundle: '{"resourceType":"Patient"}' }
        result = run(test, inputs)
        expect(result.result).to eq('fail')
      end

      it 'fails when the notification bundle does not contain a Parameters instance' do
        inputs = { access_token:, notification_bundle: '{"resourceType":"Bundle"}' }
        result = run(test, inputs)
        expect(result.result).to eq('fail')
      end

      it 'fails when the notification bundle Parameters instance does not contain a subscription parameter entry' do
        inputs = { access_token:,
                   notification_bundle:
                    '{"resourceType":"Bundle", "entry":[{"resource":{"resourceType":"Parameters"}}]}' }
        result = run(test, inputs)
        expect(result.result).to eq('fail')
      end
    end
  end
end
