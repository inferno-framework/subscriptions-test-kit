require_relative 'capability_statement/cs_conformance_test'
require_relative 'capability_statement/topic_discovery_test'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class CapabilityStatementGroup < Inferno::TestGroup
      id :subscriptions_r4_server_capability_statement
      title 'Capability Statement Verification'
      description %(
        Verify the Backport Subscriptions Server has a conformant Capability Statement and that it declares support for the
        Backport Subscription Profile on the Subscription resource in the rest field. Then the group will verify if the
        server supports topic discovert via the Capability Statement, which is an optional requirement.
      )

      run_as_group

      test from: :subscriptions_r4_server_cs_conformance
      test from: :subscriptions_r4_server_topic_discovery
    end
  end
end
