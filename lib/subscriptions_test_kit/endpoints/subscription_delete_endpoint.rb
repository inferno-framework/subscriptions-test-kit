require_relative '../tags'
require_relative '../suites/subscriptions_r5_backport_r4_client/common/subscription_simulation_utils'

module SubscriptionsTestKit
  class SubscriptionDeleteEndpoint < Inferno::DSL::SuiteEndpoint
    include SubscriptionsR5BackportR4Client::SubscriptionSimulationUtils

    error_response_format :operation_outcome

    def test_run_identifier
      request.headers['authorization']&.delete_prefix('Bearer ')
    end

    def make_response
      unless subscription_change_allowed?
        reject_subscription_change
        return
      end

      subscription_id = request.params[:id]
      subscription = find_subscription(test_run.test_session_id)

      if subscription.present? && subscription.id == subscription_id
        # Deleting an already deleted resource has no effect, so respond the same way
        response.status = 204
      else
        fhir_error_response(404, 'not-found', "No subscription exists with ID #{subscription_id}")
      end
    end

    # Rejected changes are left untagged so that they are not treated as part of the update and delete tests
    def tags
      return [] unless subscription_change_allowed?

      [SUBSCRIPTION_DELETE_TAG, request.params[:id]]
    end
  end
end
