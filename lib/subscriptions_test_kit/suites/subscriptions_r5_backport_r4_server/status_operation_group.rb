require_relative 'status_operation/status_invocation_test'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class StatusOperationGroup < Inferno::TestGroup
      id :subscriptions_r4_server_status_operation
      title 'Subscription $status Operation Verification'
      description %(
        This test group verifies that the Backport Subscriptions Server supports the $status operation.
      )
      
      test from: :subscriptions_r4_server_status_invocation
    end
  end
end
