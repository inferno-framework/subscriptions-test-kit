require_relative '../common/subscription_update_delete'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class DeleteTest < Inferno::Test
      include SubscriptionUpdateDelete

      id :subscriptions_r4_server_delete
      title 'Server supports deleting a Subscription'
      description %(
        A server SHOULD be capable of deleting a Subscription resource using `DELETE [base]/Subscription/[id]`.

        This test sends a FHIR [delete](https://hl7.org/fhir/R4/http.html#delete) request for the Subscription
        created during the Subscription Workflow tests. Inferno verifies that the server responds with a
        `200`, `202`, or `204` status. Unless the server indicates that the deletion has been accepted but
        not yet completed (`202`), Inferno also verifies that a subsequent read of the Subscription returns
        a `404` or `410` status.
      )

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@127'

      run do
        subscription_id = created_subscription_id

        fhir_delete(:subscription, subscription_id)
        assert_response_status([200, 202, 204])
        pass_if(request.status == 202, 'Server accepted the deletion request but has not yet completed it.')

        fhir_read(:subscription, subscription_id)
        assert_response_status([404, 410])
      end
    end
  end
end
