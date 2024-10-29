require_relative 'subscription_rejection/reject_subscription_channel_endpoint_test'
require_relative 'subscription_rejection/reject_subscription_channel_payload_combo_test'
require_relative 'subscription_rejection/reject_subscription_channel_type_test'
require_relative 'subscription_rejection/reject_subscription_cross_version_extension_test'
require_relative 'subscription_rejection/reject_subscription_filter_test'
require_relative 'subscription_rejection/reject_subscription_payload_type_test'
require_relative 'subscription_rejection/reject_subscription_topic_test'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class SubscriptionRejectionGroup < Inferno::TestGroup
      id :subscriptions_r4_server_subscription_rejection
      title 'Subscription Creation Rejection Verification'
      description %(
        This test group verifies that the Backport Subscriptions Server supports rejecting unsupported
        Subscription creation requests.
      )

      input_order :url, :credentials, :subscription_resource, :unsupported_subscription_topic,
                  :unsupported_subscription_filter, :unsupported_subscription_channel_type,
                  :unsupported_subscription_channel_endpoint, :unsupported_subscription_payload_type,
                  :unsupported_subscription_channel_payload_combo

      # test from: :subscriptions_r4_server_reject_subscriptions
      test from: :subscriptions_r4_server_reject_subscription_cross_version_extension
      test from: :subscriptions_r4_server_reject_subscription_topic
      test from: :subscriptions_r4_server_reject_subscription_filter
      test from: :subscriptions_r4_server_reject_subscription_channel_type
      test from: :subscriptions_r4_server_reject_subscription_channel_endpoint
      test from: :subscriptions_r4_server_reject_subscription_payload_type
      test from: :subscriptions_r4_server_reject_subscription_channel_payload_combo
    end
  end
end
