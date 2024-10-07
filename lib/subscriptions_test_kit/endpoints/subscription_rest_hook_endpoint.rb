require_relative '../tags'
module SubscriptionsTestKit
  class SubscriptionRestHookEndpoint < Inferno::DSL::SuiteEndpoint
    def test_run_identifier
      bearer_token = extract_bearer_token(request)
      "notification #{bearer_token}"
    end

    # Header expected to be a bearer token of the form "Bearer <token>"
    def extract_bearer_token(request)
      request.headers['authorization']&.delete_prefix('Bearer ')
    end

    def notification_extract_subscription_status(request)
      notification_bundle_entries = request.params[:entry]
      return if notification_bundle_entries.blank?

      subscription_status_entry = notification_bundle_entries.find do |entry|
        entry[:resource][:resourceType] == 'Parameters'
      end

      subscription_status_entry[:resource]
    end

    def extract_notification_type(request)
      subscription_status = notification_extract_subscription_status(request)
      return unless subscription_status.present?

      notification_type = subscription_status[:parameter].find { |param| param[:name] == 'type' }
      notification_type[:valueCode]
    end

    def subscription_status_extract_parameter(parameters, param_name)
      return unless parameters.present?

      parameters.find do |entry|
        entry[:name] == param_name
      end
    end

    def notification_extract_subscription_id(request)
      subscription_status = notification_extract_subscription_status(request)
      return unless subscription_status.present?

      subscription_param = subscription_status_extract_parameter(subscription_status[:parameter], 'subscription')
      return unless subscription_param.present?

      subscription_reference = subscription_param[:valueReference][:reference]
      subscription_reference.split('/').last
    end

    def make_response
      response.status = 200
    end

    def tags
      notification_type = extract_notification_type(request)
      subscription_id = notification_extract_subscription_id(request)
      [notification_type, subscription_id]
    end

    def update_result
      results_repo.update(result.id, result: 'pass') unless test.config.options[:accepts_multiple_requests]
    end
  end
end
