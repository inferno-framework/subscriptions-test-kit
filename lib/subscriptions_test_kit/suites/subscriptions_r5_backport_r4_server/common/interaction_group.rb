require_relative 'interaction/subscription_conformance_test'
require_relative 'interaction/notification_delivery_test'
require_relative 'interaction/creation_response_conformance_test'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class InteractionGroup < Inferno::TestGroup
      id :subscriptions_r4_server_interaction
      title 'Subscription Workflow Interaction'
      description %(
        Verify that the Subscription instance the tester provided is conformant, and then demonstrate the ability of the
        server under test to accept a request for the creation of a FHIR Subscription instance and deliver a
        notification for that Subscription. Inferno will act as a client, creating the Subscription and waiting for a
        notification based on it.
      )

      run_as_group

      test from: :subscriptions_r4_server_subscription_conformance
      test from: :subscriptions_r4_server_notification_delivery
      test from: :subscriptions_r4_server_creation_response_conformance
    end
  end
end
