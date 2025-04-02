# frozen_string_literal: true

require_relative 'workflow/interaction_test'
require_relative 'workflow/interaction_verification_group'
require_relative 'workflow/conformance_verification_group'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class WorkflowGroup < Inferno::TestGroup
      include URLs

      id :subscriptions_r4_client_workflow
      title 'Demonstrate the Rest-Hook Subscription Workflow'
      description %(
        This test allows the tester to demonstrate the ability of the client
        to request the creation of a FHIR Subscription instance and receive
        notifications for that Subscription.

        The tester must provide the body of an event notification
        that it expects to receive. Inferno will act as a server,
        waiting for the Subscription creation request. Once the Subscription
        has been received, Inferno will verify the endpoint using a
        handshake based off of provided notification and then send the
        provided notification after a short delay.

        Inferno will then verify that the requested Subscription
        and notification match and that the exchange is conformant.
      )
      run_as_group

      group 'Rest-Hook Subscription Interaction' do
        test from: :subscriptions_r4_client_interaction
      end

      group from: :subscriptions_r4_client_interaction_verification
      group from: :subscriptions_r4_client_conformance_verification
    end
  end
end
