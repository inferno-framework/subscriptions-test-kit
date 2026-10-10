require_relative '../common/subscription_update_delete'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class UpdatePutTest < Inferno::Test
      include SubscriptionUpdateDelete

      id :subscriptions_r4_server_update_put
      title 'Server supports updating a Subscription using PUT'
      description %(
        During this test, Inferno will send a FHIR [update](https://hl7.org/fhir/R4/http.html#update)
        (`PUT`) request to change the `reason` of the Subscription created during the "Demonstrate the
        Subscription Workflow" group. Inferno will verify that the server responds with a `200` status
        and that a subsequent read of the Subscription reflects the change.
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
