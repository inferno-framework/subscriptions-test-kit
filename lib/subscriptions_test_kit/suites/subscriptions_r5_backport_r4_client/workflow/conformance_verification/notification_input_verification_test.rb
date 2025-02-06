# frozen_string_literal: true

require_relative '../../../../common/notification_conformance_verification'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class NotificationInputVerificationTest < Inferno::Test
      include NotificationConformanceVerification

      id :subscriptions_r4_client_notification_input_verification
      title '[USER INPUT VERIFICATION] Notification Bundle Input Conformance Verification'
      description %(
        This test verifies that the notification bundle sent is conformant
        to the [R4 Topic-Based Subscription Notification Bundle
        profile](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription-notification-r4.html).
        The content of the notification will be based on the Bundle provided by the tester.
        )

      run do
        load_tagged_requests(REST_HOOK_EVENT_NOTIFICATION_TAG)
        skip_if(requests.none?, 'Inferno did not send an event notification')
        notification_verification(request.request_body, 'event-notification')
        no_error_verification('Notification bundle was not conformant, see error messages')
      end
    end
  end
end
