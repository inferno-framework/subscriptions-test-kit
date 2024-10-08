# frozen_string_literal: true

require_relative 'interaction_verification/handshake_notification_verification_test'
require_relative 'interaction_verification/event_notification_verification_test'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class InteractionVerificationGroup < Inferno::TestGroup
      id :subscriptions_r4_client_interaction_verification
      title 'Rest-Hook Subscription Interaction Verification'

      test from: :subscriptions_r4_client_handshake_notification_verification
      test from: :subscriptions_r4_client_event_notification_verification
    end
  end
end