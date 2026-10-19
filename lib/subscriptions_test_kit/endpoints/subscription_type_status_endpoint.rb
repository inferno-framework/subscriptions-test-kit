require_relative 'subscription_status_endpoint'

module SubscriptionsTestKit
  class SubscriptionTypeStatusEndpoint < SubscriptionStatusEndpoint
    INPUT_VALUE_TYPES = { 'id' => 'valueId', 'status' => 'valueCode' }.freeze

    # Not inherited: SuiteEndpoint stores the format per class
    error_response_format :operation_outcome

    def requested_subscription?(subscription, status_code)
      inputs = request.get? ? query_inputs : body_inputs
      return false if inputs.nil?

      return true if (inputs['id'].empty? || inputs['id'].include?(subscription.id)) &&
                     (inputs['status'].empty? || inputs['status'].include?(status_code))

      fhir_error_response(404, 'not-found')
      false
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
        [name, find_params(params, name).map { |p| p.public_send(value_type) }]
      end
    end

    def input_type_errors(params)
      INPUT_VALUE_TYPES.filter_map do |name, value_type|
        next if find_params(params, name).all? { |p| valid_input_value?(p, value_type) }

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

    def find_params(params, name)
      params.parameter.filter { |p| p.name == name }
    end
  end
end
