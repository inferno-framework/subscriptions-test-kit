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
      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@113'

      run do
        load_tagged_requests(REST_HOOK_EVENT_NOTIFICATION_TAG)
        skip_if(requests.none?, 'Inferno did not send an event notification')
        token = SecureRandom.hex(32)
        wait(
          identifier: token,
          message: %(
            I attest that the client application successfully processed the event notification sent by Inferno.

            [Click here](#{resume_pass_url}?test_run_identifier=#{token}) if the above statement is **true**.

            [Click here](#{resume_fail_url}?test_run_identifier=#{token}) if the above statement is **false**.
          )
        )
      end
    end
  end
end