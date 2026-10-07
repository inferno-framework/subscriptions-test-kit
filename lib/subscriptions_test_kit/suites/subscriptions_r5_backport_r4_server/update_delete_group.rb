require_relative 'update_delete/update_put_test'
require_relative 'update_delete/update_patch_test'
require_relative 'update_delete/delete_test'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class UpdateDeleteGroup < Inferno::TestGroup
      id :subscriptions_r4_server_update_delete
      title 'Subscription Update and Deletion Verification'
      description %(
        Verify that the server under test supports modifying and deleting Subscription resources as
        recommended by the [R4 Subscription Server CapabilityStatement](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/CapabilityStatement-backport-subscription-server-r4.html).
        Servers SHOULD support modifying Subscriptions using either `PUT` or `PATCH`, so the tests for each
        are optional, and SHOULD support deleting Subscriptions.

        These tests update and then delete the Subscription created during the Subscription Workflow tests,
        so those tests must be run first. Because the Subscription is deleted, the Subscription Workflow
        tests must be run again before re-running these tests or other tests that rely on that Subscription,
        such as the `$status` operation tests.
      )
      optional

      test from: :subscriptions_r4_server_update_put
      test from: :subscriptions_r4_server_update_patch
      test from: :subscriptions_r4_server_delete
    end
  end
end
