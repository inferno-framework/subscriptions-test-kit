RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Client::InteractionTest, :request do
  let(:suite_id) { 'subscriptions_r5_backport_r4_client' }

  describe 'performing interactions with the client under test' do
    let(:access_token) { '1234' }

    # Pattern for execution with tester inputs
    # 1. get the runnable into the `test` variable using the find_test function,
    #    e.g., let(:test) { find_test(suite, described_class.id) }
    # 2. create input hash, e.g., inputs = { ... }
    # 3. pass to the run method (defined in the shared context), e.g., result = run(test, inputs)
    # let(:test) { find_test(suite, described_class.id) }
    let(:test) { described_class }

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
        binding.pry
        result = run(test, inputs)
        expect(result.result).to eq('wait')

        get("#{resume_pass_url}?test_run_identifier=#{access_token}")

        result = results_repo.find(result.id)
        expect(result.result).to eq('pass')
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
