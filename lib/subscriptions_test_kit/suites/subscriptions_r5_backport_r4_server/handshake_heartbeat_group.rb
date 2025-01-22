require_relative 'handshake_heartbeat/handshake_conformance_test'
require_relative 'handshake_heartbeat/heartbeat_conformance_test'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class HandshakeHeartbeatGroup < Inferno::TestGroup
      id :subscriptions_r4_server_handshake_heartbeat
      title 'Backport Subscription Handshake and Heartbeat Notification Verification'
      description %(
        Verify that all Handshake ane Heartbeat Notifications received during previous tests are conformant to the
        [R4 Topic-Based Subscription Notification Bundle](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription-notification-r4.html)
        profile.
      )

      test from: :subscriptions_r4_server_handshake_conformance
      test from: :subscriptions_r4_server_heartbeat_conformance
    end
  end
end
