require_relative 'coverage/capability_statement_group'
require_relative 'coverage/event_notification_group'
require_relative 'coverage/handshake_heartbeat_group'
require_relative 'coverage/status_operation_group'
require_relative 'coverage/subscription_rejection_group'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    module Coverage
      class GroupForCoverage < Inferno::TestGroup
        id :subscriptions_r4_server_coverage
        title 'Demonstrate coverage of all Subscription Backport IG requirements'
        description %(
          Demonstrate that the server covers all requirements placed on
          servers by the IG.
        )

        group from: :subscriptions_r4_server_capability_statement
        group from: :subscriptions_r4_server_event_notification
        group from: :subscriptions_r4_server_handshake_heartbeat
        group from: :subscriptions_r4_server_status_operation
        group from: :subscriptions_r4_server_subscription_rejection
      end
    end
  end
end
