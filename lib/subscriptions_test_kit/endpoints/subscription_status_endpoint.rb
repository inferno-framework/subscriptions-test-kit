require_relative '../tags'
require_relative '../suites/subscriptions_r5_backport_r4_client/common/subscription_simulation_utils'

module SubscriptionsTestKit
  # Handles $status invoked on a Subscription instance; SubscriptionTypeStatusEndpoint handles the type-level invocation
  class SubscriptionStatusEndpoint < Inferno::DSL::SuiteEndpoint
    include SubscriptionsR5BackportR4Client::SubscriptionSimulationUtils

    INPUT_VALUE_TYPES = { 'id' => 'valueId', 'status' => 'valueCode' }.freeze

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

      inputs = request.get? ? query_inputs : body_inputs
      return if inputs.nil?

      status_code = current_subscription_status_code(subscription)
      unless subscription_matches?(inputs, subscription, status_code)
        fhir_error_response(404, 'not-found')
        return
      end

      notification_json = notification_bundle_input(result)
      subscription_url = "#{base_subscription_url}/#{subscription.id}"
      subscription_topic = subscription.criteria
      event_count = determine_event_count(test_run.test_session_id)
      response.status = 200
      response.body = derive_status_bundle(notification_json, subscription_url, subscription_topic, status_code,
                                           event_count, request.url).to_json
    end

    def requested_ids(_inputs)
      [request.params[:id]]
    end

    def subscription_matches?(inputs, subscription, status_code)
      ids = requested_ids(inputs)
      (ids.empty? || ids.include?(subscription.id)) &&
        (inputs['status'].empty? || inputs['status'].include?(status_code))
    end

    # request.params keeps only the last value of a repeated query parameter
    def query_inputs
      query = ::Rack::Utils.parse_query(request.query_string)
      INPUT_VALUE_TYPES.keys.to_h { |name| [name, Array(query[name])] }
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
        [name, find_params(params, name).map { |p| p.public_send(value_type) }]
      end
    end

    def input_type_errors(params)
      INPUT_VALUE_TYPES.filter_map do |name, value_type|
        next if find_params(params, name).all? { |p| p.public_send(value_type).present? }

        "The `#{name}` parameter must be sent as `#{value_type}`."
      end
    end

    def parse_parameters_body
      return FHIR::Parameters.new if request.body.string.blank?

      params = FHIR.from_contents(request.body.string)
      return params if params.is_a?(FHIR::Parameters)

      fhir_error_response(400, 'invalid', 'Invalid Parameters in request body')
      nil
    rescue StandardError
      fhir_error_response(400, 'invalid', 'Invalid Parameters in request body')
      nil
    end

    def tags
      [SUBSCRIPTION_STATUS_TAG]
    end

    def find_params(params, name)
      params.parameter.filter { |p| p.name == name }
    end

    def base_subscription_url
      request.url.sub(/(#{Regexp.escape(FHIR_SUBSCRIPTION_PATH)}).*/, '\1')
    end
  end
end
