require_relative '../tags'
require_relative '../suites/subscriptions_r5_backport_r4_client/common/subscription_simulation_utils'

module SubscriptionsTestKit
  # Handles $status invoked on a Subscription instance (`Subscription/[id]/$status`) or on the type
  # (`Subscription/$status`). The `id` and `status` inputs are ignored at the instance level.
  class SubscriptionStatusEndpoint < Inferno::DSL::SuiteEndpoint
    include SubscriptionsR5BackportR4Client::SubscriptionSimulationUtils

    INPUT_VALUE_TYPES = { 'id' => 'valueId', 'status' => 'valueCode' }.freeze

    error_response_format :operation_outcome

    def test_run_identifier
      request.headers['authorization']&.delete_prefix('Bearer ')
    end

    def make_response
      response.format = :json
      type_level? ? make_type_response : make_instance_response
    end

    def make_instance_response
      subscription = find_current_subscription(test_run.test_session_id)
      if subscription.blank? || request.params[:id] != subscription.id
        fhir_error_response(404, 'not-found')
        return
      end

      respond_with_status(subscription)
    end

    # Search semantics: no matching Subscription yields an empty searchset Bundle
    def make_type_response
      inputs = request.get? ? query_inputs : body_inputs
      return if inputs.nil?

      subscription = find_current_subscription(test_run.test_session_id)
      if subscription.present? && inputs_match?(inputs, subscription)
        respond_with_status(subscription)
        return
      end

      response.status = 200
      response.body = empty_status_bundle(request.url).to_json
    end

    # Repeated values of an input are joined via OR
    def inputs_match?(inputs, subscription)
      (inputs['id'].empty? || inputs['id'].include?(subscription.id)) &&
        (inputs['status'].empty? || inputs['status'].include?(current_subscription_status_code(subscription)))
    end

    def respond_with_status(subscription)
      notification_json = notification_bundle_input(result)
      subscription_url = "#{base_subscription_url}/#{subscription.id}"
      subscription_topic = subscription.criteria
      event_count = determine_event_count(test_run.test_session_id)
      response.status = 200
      response.body = derive_status_bundle(notification_json, subscription_url, subscription_topic,
                                           current_subscription_status_code(subscription), event_count,
                                           request.url).to_json
    end

    def type_level?
      request.path.end_with?(FHIR_SUBSCRIPTION_RESOURCE_STATUS_PATH)
    end

    # request.params keeps only the last value of a repeated query parameter.
    # Renders an error response and returns nil if any input is given without a value.
    def query_inputs
      query = ::Rack::Utils.parse_query(request.query_string)
      inputs = INPUT_VALUE_TYPES.keys.to_h { |name| [name, query.key?(name) ? [query[name]].flatten : []] }

      blank_inputs = inputs.select { |_name, values| values.any?(&:blank?) }.keys
      return inputs if blank_inputs.empty?

      fhir_error_response(400, 'invalid', blank_inputs.map do |name|
        "The `#{name}` query parameter must have a value."
      end.join(' '))
      nil
    end

    # Renders an error response and returns nil if the body is not a Parameters resource with correctly typed inputs
    def body_inputs
      params = parse_parameters_body
      return if params.nil?

      type_errors = input_type_errors(params)
      if type_errors.any?
        fhir_error_response(400, 'invalid', type_errors.join(' '))
        return
      end

      INPUT_VALUE_TYPES.to_h do |name, value_type|
        [name, find_all_parameters(params, name).map { |p| p.public_send(value_type) }]
      end
    end

    def input_type_errors(params)
      INPUT_VALUE_TYPES.filter_map do |name, value_type|
        next if find_all_parameters(params, name).all? { |p| valid_input_value?(p, value_type) }

        "The `#{name}` parameter must have a non-empty `#{value_type}` and no other value."
      end
    end

    def valid_input_value?(param, value_type)
      value = param.public_send(value_type)
      value.is_a?(String) && value.present? &&
        param.to_hash.keys.grep(/\Avalue[A-Z]/) == [value_type]
    end

    def parse_parameters_body
      return FHIR::Parameters.new if request.body.string.blank?

      params = begin
        FHIR.from_contents(request.body.string)
      rescue StandardError
        nil
      end
      return params if params.is_a?(FHIR::Parameters)

      fhir_error_response(400, 'invalid', 'Invalid Parameters in request body')
      nil
    end

    def tags
      [SUBSCRIPTION_STATUS_TAG]
    end

    def base_subscription_url
      request.url.sub(/(#{Regexp.escape(FHIR_SUBSCRIPTION_PATH)}).*/, '\1')
    end
  end
end
