# frozen_string_literal: true

require_relative 'conformance_verification/subscription_verification_test'
require_relative 'conformance_verification/notification_input_verification_test'
require_relative 'conformance_verification/notification_input_payload_verification_test'
require_relative 'conformance_verification/processing_attestation_test'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class ConformanceVerificationGroup < Inferno::TestGroup
      id :subscriptions_r4_client_conformance_verification
      title 'Rest-Hook Subscription Conformance Verification'

      test from: :subscriptions_r4_client_subscription_verification
      test from: :subscriptions_r4_client_notification_input_verification
      test from: :subscriptions_r4_client_notification_input_payload_verification
      test from: :subscriptions_r4_client_processing_attestation
    end
  end
end
