require_relative '../tags'
require_relative '../suites/subscriptions_r5_backport_r4_client/common/subscription_simulation_utils'

module SubscriptionsTestKit
  # Handles $status invoked on a Subscription instance; SubscriptionTypeStatusEndpoint handles the type-level invocation
  class SubscriptionStatusEndpoint < Inferno::DSL::SuiteEndpoint
    include SubscriptionsR5BackportR4Client::SubscriptionSimulationUtils

    error_response_format :operation_outcome

    def test_run_identifier
      request.headers['authorization']&.delete_prefix('Bearer ')
    end

    def make_response
      response.format = :json
      subscription = find_current_subscription(test_run.test_session_id)
      if subscription.blank?
        fhir_error_response(404, 'not-found')
        return
      end

      status_code = current_subscription_status_code(subscription)
      return unless requested_subscription?(subscription, status_code)

      notification_json = notification_bundle_input(result)
      subscription_url = "#{base_subscription_url}/#{subscription.id}"
      subscription_topic = subscription.criteria
      event_count = determine_event_count(test_run.test_session_id)
      response.status = 200
      response.body = derive_status_bundle(notification_json, subscription_url, subscription_topic, status_code,
                                           event_count, request.url).to_json
    end

    # Renders an error response and returns false if the request does not select the current Subscription.
    # The operation's `id` and `status` inputs are ignored at the instance level.
    def requested_subscription?(subscription, _status_code)
      return true if request.params[:id] == subscription.id

      fhir_error_response(404, 'not-found')
      false
    end

    def tags
      [SUBSCRIPTION_STATUS_TAG]
    end

    def base_subscription_url
      request.url.sub(/(#{Regexp.escape(FHIR_SUBSCRIPTION_PATH)}).*/, '\1')
    end
  end
end
