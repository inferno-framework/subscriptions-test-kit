# frozen_string_literal: true

require_relative 'workflow/interaction_test'
require_relative 'workflow/interaction_verification_group'
require_relative 'workflow/conformance_verification_group'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class WorkflowGroup < Inferno::TestGroup
      include URLs

      id :subscriptions_r5_backport_r4_client_workflow
      title 'Demonstrate the Rest-Hook Subscription Workflow'
      description %(
          Demonstrate the ability of the client to request the
          creation of a FHIR Subscription instance and receive a notification
          for that Subscription. The tester must provide the body of a Notification
          that it expects to receive. Inferno will act as a server,
        waiting for the Subscription creation request and then sending the
        notification. Inferno will then verify that the provided Subscription
        and notification match and that the exchange is conformant.
      )
      run_as_group

      group 'Rest-Hook Subscription Interaction' do
        test from: :subscriptions_r5_backport_r4_client_interaction
      end

      group from: :subscriptions_r5_backport_r4_client_interaction_verification
      group from: :subscriptions_r5_backport_r4_client_conformance_verification
    end
  end
end
