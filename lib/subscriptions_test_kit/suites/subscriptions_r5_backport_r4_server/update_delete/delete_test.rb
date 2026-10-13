require_relative '../common/subscription_update_delete'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class DeleteTest < Inferno::Test
      include SubscriptionUpdateDelete

      id :subscriptions_r4_server_delete
      title 'Server supports deleting a Subscription'
      description %(
        During this test, Inferno will send a FHIR [delete](https://hl7.org/fhir/R4/http.html#delete) request
        for the Subscription created during the "Demonstrate the Subscription Workflow" group. Inferno will
        verify that the server responds with a `200`, `202`, or `204` status and that a subsequent read of
        the Subscription returns a `404` or `410` status.
      )
      optional
      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@127'

      run do
        subscription_id = created_subscription_id

        fhir_delete(:subscription, subscription_id)
        assert_response_status([200, 202, 204])

        fhir_read(:subscription, subscription_id)
        assert_response_status([404, 410])
      end
    end
  end
end
