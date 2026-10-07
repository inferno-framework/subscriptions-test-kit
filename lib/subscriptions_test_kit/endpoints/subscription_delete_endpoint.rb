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
      subscription_id = request.params[:id]
      subscription = find_subscription(test_run.test_session_id)

      if subscription.present? && subscription.id == subscription_id
        # Deleting an already deleted resource has no effect, so respond the same way
        response.status = 204
      else
        response.format = :json
        response.status = 404
        response.body = operation_outcome('error', 'not-found',
                                          "No subscription exists with ID #{subscription_id}").to_json
      end
    end

    def tags
      [SUBSCRIPTION_DELETE_TAG, request.params[:id]]
    end
  end
end
