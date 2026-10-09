# frozen_string_literal: true

require_relative '../../common/subscription_simulation_utils'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class DeleteVerificationTest < Inferno::Test
      include SubscriptionSimulationUtils

      id :subscriptions_r4_client_delete_verification
      title 'Client Subscription Delete Conformance Verification'
      description %(
        This test verifies that the client under test sent a conformant
        [delete](https://hl7.org/fhir/R4/http.html#delete) request for the Subscription it created
        in this session to Inferno's simulated FHIR server.
      )

      run do
        subscription = find_subscription(test_session_id)
        skip_if(subscription.nil?, 'No Subscription was created in this session')

        load_tagged_requests(SUBSCRIPTION_DELETE_TAG)
        skip_if(requests.none?, 'Inferno did not receive a Subscription delete request')

        delete_request = requests.find { |r| r.tags.include?(subscription.id) }
        assert(delete_request.present?, %(
          Subscription delete request(s) did not target the created Subscription with id #{subscription.id}.
          Requested URL(s): #{requests.map { |r| "`#{r.url}`" }.join(', ')}
        ))
      end
    end
  end
end
