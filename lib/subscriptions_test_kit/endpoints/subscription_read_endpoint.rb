require_relative '../tags'
require_relative '../suites/subscriptions_r5_backport_r4_client/common/subscription_simulation_utils'

module SubscriptionsTestKit
  class SubscriptionReadEndpoint < Inferno::DSL::SuiteEndpoint
    include SubscriptionsR5BackportR4Client::SubscriptionSimulationUtils

    error_response_format :operation_outcome

    def test_run_identifier
      request.headers['authorization']&.delete_prefix('Bearer ')
    end

    def make_response
      response.format = :json
      subscription_id = request.params[:id]

      subscription = find_current_subscription(test_run.test_session_id)

      if subscription.present? && subscription.id == subscription_id
        status_code = current_subscription_status_code(subscription)
        response.body = subscription.source_hash.merge('status' => status_code).to_json
      else
        fhir_error_response(404, 'not-found', "No subscription exists with ID #{subscription_id}")
      end
    end

    def tags
      [SUBSCRIPTION_READ_TAG]
    end
  end
end
