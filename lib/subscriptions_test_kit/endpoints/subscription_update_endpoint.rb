require_relative '../tags'
require_relative '../suites/subscriptions_r5_backport_r4_client/common/subscription_simulation_utils'

module SubscriptionsTestKit
  class SubscriptionUpdateEndpoint < Inferno::DSL::SuiteEndpoint
    include SubscriptionsR5BackportR4Client::SubscriptionSimulationUtils

    error_response_format :operation_outcome

    def test_run_identifier
      request.headers['authorization']&.delete_prefix('Bearer ')
    end

    def make_response
      if subscription_change_allowed?
        update_subscription
      else
        reject_subscription_change
      end
    end

    def update_subscription
      response.format = :json
      subscription_id = request.params[:id]

      current_subscription = find_current_subscription(test_run.test_session_id)
      unless current_subscription.present? && current_subscription.id == subscription_id
        fhir_error_response(404, 'not-found', "No subscription exists with ID #{subscription_id}")
        return
      end

      # We have to manipulate the raw hash so that we don't lose the _payload primitive extension
      subscription_hash = requested_subscription_hash(current_subscription)
      return if subscription_hash.nil?

      begin
        subscription = FHIR.from_contents(subscription_hash.to_json)
      rescue StandardError
        subscription = nil
      end

      verification_outcome = verify_subscription(subscription)
      if verification_outcome.present?
        response.status = 400
        response.body = verification_outcome.to_json
        return
      end

      unless subscription.id == subscription_id
        fhir_error_response(400, 'invalid', "Updated Subscription id '#{subscription.id}' does not match the id " \
                                            "'#{subscription_id}' in the request URL")
        return
      end

      subscription_hash['status'] = current_subscription_status_code(subscription)
      subscription_hash['channel']['payload'] = actual_mime_type(subscription)
      response.status = 200
      response.body = subscription_hash.to_json
    end

    # The requested state of the Subscription as a raw hash, or nil if an error response has been set
    def requested_subscription_hash(_current_subscription)
      subscription_hash = begin
        JSON.parse(request.body.string)
      rescue JSON::ParserError
        nil
      end
      return subscription_hash if subscription_hash.is_a?(Hash)

      fhir_error_response(400, 'invalid', 'No recognized R4 Subscription in request body')
      nil
    end

    # Rejected changes are left untagged so that they are not treated as part of the update and delete tests
    def tags
      return [] unless subscription_change_allowed?

      [SUBSCRIPTION_UPDATE_TAG, request.params[:id]]
    end
  end
end
