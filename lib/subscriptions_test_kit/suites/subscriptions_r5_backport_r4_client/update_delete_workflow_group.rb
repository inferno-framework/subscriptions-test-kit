# frozen_string_literal: true

require_relative 'update_delete_workflow/update_delete_interaction_test'
require_relative 'update_delete_workflow/update_delete_conformance_verification_group'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class UpdateDeleteWorkflowGroup < Inferno::TestGroup
      id :subscriptions_r4_client_update_delete_workflow
      title 'Demonstrate Subscription Update and Deletion'
      description %(
        During this test, the tester will demonstrate the ability of the client
        to update and/or delete the Subscription instance that it created
        during the *Demonstrate the Rest-Hook Subscription Workflow* tests.
        Those tests must be run first in the same session.

        Inferno will wait for the client to send update and delete requests and
        will then verify that the requests are conformant. Note that
        - Update and delete requests are only accepted by Inferno while
          this group is waiting.
        - If this group is re-run, Inferno will forget about the previous
          update and delete interactions sent by the Subscriptions client.
          The Subscriptions client can interact with it as it was after
          it was created. If the Subscriptions client cannot reactivate
          the deleted Subscription and make updates to it again, re-run
          the *Demonstrate the Rest-Hook Subscription Workflow* group
          to create a new Subscription.
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
