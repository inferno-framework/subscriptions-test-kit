module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    module SubscriptionStatusOperation
      def no_error_verification(message)
        assert messages.none? { |msg| msg[:type] == 'error' }, message
      end

      def find_elem(resource_array, param_name)
        resource_array.find do |param|
          param.name == param_name
        end
      end

      def execute_subscription_status_operation(subscription_id)
        fhir_operation("Subscription/#{subscription_id}/$status", operation_method: :get)
        assert_response_status(200)
        assert_resource_type('Bundle')

        unless resource.type == 'searchset'
          add_message('error',
                      "Bundle returned from $status operation should be type 'searchset', was #{resource.type}")
        end

        assert_valid_resource

        resource.entry
      end

      def subscription_ref_found?(entry, subscription_id)
        subscription_param = find_elem(entry.resource.parameter, 'subscription')
        subscription_ref = subscription_param.valueReference.reference
        return false if subscription_ref.blank?

        subscription_ref.split('/').last == subscription_id
      end

      def perform_subscription_status_test(subscription_id, status = nil)
        bundle_entries = execute_subscription_status_operation(subscription_id)
        subscription_status_entry = bundle_entries.find do |entry|
          entry.resource.resourceType == 'Parameters' && subscription_ref_found?(entry, subscription_id)
        end
        assert(subscription_status_entry,
               "No Subscription status with id #{subscription_id} returned from $status operation")

        subscription_status_resource = subscription_status_entry.resource
        assert_valid_resource(resource: subscription_status_resource,
                              profile_url: 'http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/backport-subscription-status-r4')

        subscription_status = find_elem(subscription_status_resource.parameter, 'status')

        return unless status.present?

        assert(subscription_status.valueCode == status, %(
              The Subscription resource should have it's `status` set to #{status}, was
              `#{subscription_status.valueCode}`))
      end
    end
  end
end
