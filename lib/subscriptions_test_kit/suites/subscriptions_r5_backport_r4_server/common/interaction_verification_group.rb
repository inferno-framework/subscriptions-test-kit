require_relative 'interaction_verification/notification_conformance_test'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class InteractionVerificationGroup < Inferno::TestGroup
      id :subscriptions_r4_server_interaction_verification
      title 'Subscription Workflow Interaction Verification'
      description %(
        Inferno takes the received event-notification Bundle and verifies that it is conformant to the
        [R4 Topic-Based Subscription Notification Bundle](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription-notification-r4.html)
        profle.
      )

      run_as_group

      test from: :subscriptions_r4_server_notification_conformance
    end
  end
end
