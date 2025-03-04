require_relative 'common/interaction_group'
require_relative 'common/interaction_verification_group'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class WorkflowGroup < Inferno::TestGroup
      id :subscriptions_r4_server_workflow
      title 'Demonstrate the subscription workflow'
      description %(
        Demonstrate the ability of the server to accept a request for the
        creation of a FHIR Subscription instance and deliver an event notification
        for that Subscription. The tester must provide a Subscription instance
        that the server under test supports. Inferno will act as a client,
        creating the Subscription and waiting for notifications based on it.
        Inferno will then verify that an event notification has been received
        for the created Subscription and that the exchange is conformant.
      )

      run_as_group

      input_order :url, :credentials, :access_token, :subscription_resource

      group from: :subscriptions_r4_server_interaction
      group from: :subscriptions_r4_server_interaction_verification
    end
  end
end
