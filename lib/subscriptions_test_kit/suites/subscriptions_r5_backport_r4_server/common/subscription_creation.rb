module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    module SubscriptionCreation
      def no_error_verification(message)
        assert messages.none? { |msg| msg[:type] == 'error' }, message
      end

      def json_parse(json)
        JSON.parse(json)
      rescue JSON::ParserError
        add_message('error', "#{request_number}Invalid JSON.")
        false
      end

      def get_new_subscription_value(subscription, field_path)
        field_path.reduce(subscription) { |obj, path| obj[path] }
      end

      def normalize_value(value)
        return value.deep_transform_keys(&:to_sym) if value.is_a?(Hash)

        value
      end

      def send_unsupported_subscription(subscription, unsupported_type, field_paths, subscription_field_old_values)
        fhir_operation('/Subscription', body: subscription)

        return if request.status != 201

        new_subscription = json_parse(request.response_body)
        return unless new_subscription

        altered_field = false
        field_paths.each_with_index do |field_path, index|
          subscription_field_new_value = get_new_subscription_value(new_subscription, field_path)
          new_value = normalize_value(subscription_field_new_value)
          old_value = normalize_value(subscription_field_old_values[index])

          if new_value != old_value
            altered_field = true
            break
          end
        end

        return if altered_field

        add_message('error', %(
            Sending a Subscription with #{unsupported_type} should be rejected, or the Subscription should be
            altered to fix the unsupported value.))
      end

      def subscription_payload_type(subscription)
        return unless subscription['channel']['_payload']

        payload_extension = subscription['channel']['_payload']['extension'].find do |ext|
          ext['url'].ends_with?('/backport-payload-content')
        end
        payload_extension['valueCode']
      end

      def send_subscription(subscription)
        tags = ['subscription_creation']
        payload_type = subscription_payload_type(subscription)
        tags.append(payload_type) if payload_type.present?

        fhir_operation('/Subscription', body: subscription, tags:)
        assert_response_status(201)
        payload_type
      end
    end
  end
end
