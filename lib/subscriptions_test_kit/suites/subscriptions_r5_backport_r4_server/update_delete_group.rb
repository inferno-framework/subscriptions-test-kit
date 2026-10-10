require_relative 'update_delete/update_put_test'
require_relative 'update_delete/update_patch_test'
require_relative 'update_delete/delete_test'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class UpdateDeleteGroup < Inferno::TestGroup
      id :subscriptions_r4_server_update_delete
      title 'Subscription Update and Deletion Verification'
      description %(
        During this group, Inferno will verify that the Subscriptions server supports requests that
        modify and delete Subscription resources.

        This group must be run after the "Demonstrate the Subscription Workflow" group because
        it updates and then deletes the Subscription created during that group. Because the
        Subscription is deleted, the "Demonstrate the Subscription Workflow" tests must be run
        again before re-running this group or others, like the "Subscription $status Operation
        Verification" group, that rely on that Subscription.
      )
      optional

      test from: :subscriptions_r4_server_update_put
      test from: :subscriptions_r4_server_update_patch
      test from: :subscriptions_r4_server_delete
    end
  end
end
