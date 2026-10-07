# frozen_string_literal: true

require_relative 'update_delete_workflow/update_delete_interaction_test'
require_relative 'update_delete_workflow/update_delete_conformance_verification_group'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class UpdateDeleteWorkflowGroup < Inferno::TestGroup
      id :subscriptions_r4_client_update_delete_workflow
      title 'Demonstrate Subscription Update and Deletion'
      description %(
        This test allows the tester to demonstrate the ability of the client
        to update and then delete the Subscription instance that it created
        during the *Demonstrate the Rest-Hook Subscription Workflow* tests.
        Those tests must be run first in the same session.

        Inferno will act as a server, waiting for the client to send an update
        request for the Subscription followed by a delete request for the Subscription.
        Inferno will then verify that the update and delete requests are conformant.
      )
      run_as_group
      optional

      group 'Subscription Update and Delete Interaction' do
        id :subscriptions_r4_client_update_delete_workflow_interaction
        test from: :subscriptions_r4_client_update_delete_interaction
      end

      group from: :subscriptions_r4_client_update_delete_conformance_verification
    end
  end
end
