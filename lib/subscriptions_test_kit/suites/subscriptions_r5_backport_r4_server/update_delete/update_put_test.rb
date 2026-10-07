require_relative '../common/subscription_update_delete'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class UpdatePutTest < Inferno::Test
      include SubscriptionUpdateDelete

      id :subscriptions_r4_server_update_put
      title 'Server supports updating a Subscription using PUT'
      description %(
        A server SHOULD be capable of modifying a Subscription resource using either
        `PUT [base]/Subscription/[id]` or `PATCH [base]/Subscription/[id]`.

        This test reads the Subscription created during the Subscription Workflow tests, changes its `reason`,
        and sends the modified Subscription to the server in a FHIR
        [update](https://hl7.org/fhir/R4/http.html#update) (`PUT`) request. Inferno verifies that the server
        responds with a `200` status and that a subsequent read of the Subscription reflects the change.
      )
      optional

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@126'

      run do
        subscription_id = created_subscription_id
        subscription = read_subscription_json(subscription_id)
        expected_reason = updated_reason(subscription, 'PUT')

        fhir_update(raw_subscription_resource(subscription.merge('reason' => expected_reason)), subscription_id)
        assert_response_status(200)

        verify_reason_updated(subscription_id, expected_reason)
      end
    end
  end
end
