require_relative '../common/subscription_update_delete'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class UpdatePatchTest < Inferno::Test
      include SubscriptionUpdateDelete

      id :subscriptions_r4_server_update_patch
      title 'Server supports updating a Subscription using JSON Patch'
      description %(
        A server SHOULD be capable of modifying a Subscription resource using either
        `PUT [base]/Subscription/[id]` or `PATCH [base]/Subscription/[id]`.

        This test sends a [patch](https://hl7.org/fhir/R4/http.html#patch) (`PATCH`) request using
        [JSON Patch](https://datatracker.ietf.org/doc/html/rfc6902) to change the `reason` of the
        Subscription created during the Subscription Workflow tests. Inferno verifies that the server
        responds with a `200` status and that a subsequent read of the Subscription reflects the change.
        Inferno does not test XML Patch or FHIRPath Patch.
      )
      optional

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@126'

      run do
        subscription_id = created_subscription_id
        subscription = read_subscription_json(subscription_id)
        expected_reason = updated_reason(subscription, 'JSON Patch')

        fhir_patch(:subscription, subscription_id, [{ op: 'add', path: '/reason', value: expected_reason }])
        assert_response_status(200)

        verify_reason_updated(subscription_id, expected_reason)
      end
    end
  end
end
