require_relative 'interaction_verification/notification_conformance_test'
require_relative 'interaction_verification/notification_presence_test'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class InteractionVerificationGroup < Inferno::TestGroup
      id :subscriptions_r4_server_interaction_verification
      title 'Subscription Workflow Interaction Verification'
      description %(
        Inferno will verify that the sever communicated at least one notification
        (handshake, heartbeat, and/or event-notification) back to Inferno
        related to the created Subscription and that that set of notifications
        includes a conformant event-notification. Other types of notifications
        are verified during other tests.
      )

      run_as_group

      test from: :subscriptions_r4_server_notification_presence
      test from: :subscriptions_r4_server_notification_conformance
    end
  end
end
