require_relative '../common/subscription_status_operation'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class StatusInvocationTest < Inferno::Test
      include SubscriptionStatusOperation

      id :subscriptions_r4_server_status_invocation
      title 'Server supports subscription $status operation'
      description %(
        In order to claim conformance with this guide, a server: SHALL support the [$status operation](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/OperationDefinition-backport-subscription-status.html)
        on the Subscription resource. This operation is used to return the current status information about one or more
        topic-based Subscriptions in R4. The operation returns a bundle containing one or more subscription status
        resources, one per Subscription being queried. The Bundle type is "searchset". The status of the Subscription
        should be set to 'active' after a successful handshake with the rest-hook endpoint.

        This test ensures the server supports the $status operation by performing the operation and ensuring it receives
        a valid response.
      )

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@20',
                            'hl7.fhir.uv.subscriptions_1.1.0@30',
                            'hl7.fhir.uv.subscriptions_1.1.0@47'

      run do
        subscription_requests = load_tagged_requests('subscription_creation')
        success_subscription_requests =
          subscription_requests
            .select { |request| request.status == 201 }
        skip_if success_subscription_requests.empty?, %(
          No successful Subscription creation requests were made in previous tests. Must run Subscription Workflow tests
          first in order to run this test.
        )

        subscription = JSON.parse(success_subscription_requests.first.response_body)
        subscription_id = subscription['id']

        perform_subscription_status_test(subscription_id)
        no_error_verification('Subscription status response was not conformant.')
      end
    end
  end
end
