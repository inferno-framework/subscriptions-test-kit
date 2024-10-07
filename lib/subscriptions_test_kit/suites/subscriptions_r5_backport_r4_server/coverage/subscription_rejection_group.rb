require_relative 'subscription_rejection/reject_subscriptions_test'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class SubscriptionRejectionGroup < Inferno::TestGroup
      id :subscriptions_r5_backport_r4_server_subscription_rejection
      title 'Subscription Creation Rejection Verification'
      description %(
        This test group verifies that the Backport Subscriptions Server supports rejecting unsupported
        Subscription creation requests.
      )

      input_order :url, :credentials, :subscription_resource, :unsupported_subscription_topic,
                  :unsupported_subscription_filter, :unsupported_subscription_channel_type,
                  :unsupported_subscription_channel_endpoint, :unsupported_subscription_payload_type,
                  :unsupported_subscription_channel_payload_combo

      test from: :subscriptions_r5_backport_r4_server_reject_subscriptions
    end
  end
end
