require_relative '../../../suite_spec_context'

RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Client::InteractionTest do
  # ----- shared setup -----
  # 1. enables http methods and requests to suite_endpoints
  include Rack::Test::Methods
  def app
    Inferno::Web.app
  end
  # 2. defines
  # - variables: suite_id, suite, session_data_repo, validation_url, and test_session
  # - methods: run, find_test
  include_context('when testing this suite', 'subscriptions_r5_backport_r4_client')
  describe 'performing interactions with the client under test' do
    let(:access_token) { '1234' }
    let(:test) { find_test(suite, described_class.id) }

    describe 'when the tester-provided notification bundle is valid' do
      let(:valid_notification_json) do
        File.read(File.join(__dir__, '../../../..', 'fixtures', 'empty_notification_bundle_example.json'))
      end
      let(:resume_pass_url) { "/custom/#{suite_id}/resume_pass" }
      let(:resume_fail_url) { "/custom/#{suite_id}/resume_fail" }
      let(:results_repo) { Inferno::Repositories::Results.new }

      it 'passes when the tester chooses to complete the tests' do
        result = run(test, access_token:, notification_bundle: valid_notification_json)
        expect(result.result).to eq('wait')

        get("#{resume_pass_url}?test_run_identifier=#{access_token}")

        result = results_repo.find(result.id)
        expect(result.result).to eq('pass')
      end

      it 'fails when the tester chooses to fail the tests' do
        result = run(test, access_token:, notification_bundle: valid_notification_json)
        expect(result.result).to eq('wait')

        get("#{resume_fail_url}?test_run_identifier=#{access_token}")

        result = results_repo.find(result.id)
        expect(result.result).to eq('fail')
      end
    end

    describe 'when the tester-provided notification bundle is not valid' do
      it 'fails when the notification bundle is not json' do
        result = run(test, access_token:, notification_bundle: 'not json')
        expect(result.result).to eq('fail')
      end

      it 'fails when the notification bundle is not FHIR' do
        result = run(test, access_token:, notification_bundle: '{"not":"FHIR"}')
        expect(result.result).to eq('fail')
      end

      it 'fails when the notification bundle is not a Bundle' do
        result = run(test, access_token:, notification_bundle: '{"resourceType":"Patient"}')
        expect(result.result).to eq('fail')
      end

      it 'fails when the notification bundle does not contain a Parameters instance' do
        result = run(test, access_token:, notification_bundle: '{"resourceType":"Bundle"}')
        expect(result.result).to eq('fail')
      end

      it 'fails when the notification bundle Parameters instance does not contain a subscription parameter entry' do
        result = run(test, access_token:,
                           notification_bundle:
                            '{"resourceType":"Bundle", "entry":[{"resource":{"resourceType":"Parameters"}}]}')
        expect(result.result).to eq('fail')
      end
    end
  end
end
