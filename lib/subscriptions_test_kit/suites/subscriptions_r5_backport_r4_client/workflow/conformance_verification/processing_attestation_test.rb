# frozen_string_literal: true

require_relative '../../../../urls'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class ProcessingAttestationTest < Inferno::Test
      include URLs

      id :subscriptions_r4_client_processing_attestation
      title 'Client Processes Event Notification'
      description %(
        This test asks the tester to attest that the event notification sent by Inferno
        was processed correctly according to the design of the client. Thus, the details of
        what entails "correct" processing are left to the tester based on their understanding
        of what should happen when the client receives an event notification for the requested
        Subscription.
      )

      output :attest_true_url
      output :attest_false_url

      run do
        load_tagged_requests(REST_HOOK_EVENT_NOTIFICATION_TAG)
        skip_if(requests.none?, 'Inferno did not send an event notification')

        identifier = test_session_id
        attest_true_url = "#{resume_pass_url_client}?test_run_identifier=#{identifier}"
        output(attest_true_url:)
        attest_false_url = "#{resume_fail_url_client}?test_run_identifier=#{identifier}"
        output(attest_false_url:)

        wait(
          identifier:,
          message: %(
            I attest that the client application successfully processed the event notification sent by Inferno.

            [Click here](#{resume_pass_url_client}?test_run_identifier=#{token}) if the above statement is **true**.

            [Click here](#{resume_fail_url_client}?test_run_identifier=#{token}) if the above statement is **false**.
          )
        )
      end
    end
  end
end
