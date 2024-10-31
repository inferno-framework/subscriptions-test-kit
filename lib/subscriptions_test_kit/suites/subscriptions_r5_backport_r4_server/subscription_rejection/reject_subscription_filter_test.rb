require_relative '../common/subscription_creation'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class RejectSubscriptionFilterTest < Inferno::Test
      include SubscriptionCreation

      id :subscriptions_r4_server_reject_subscription_filter
      title 'Server Handles Unsupported Subscription Filters'
      description %(
        When processing a request for a Subscription a server SHOULD verify that the Subscription is supported and does
        not contain any information not implemented by the server. If the Subscription is not supported, the server
        should reject the Subscription create request, or it should attempt to adjust the Subscription. When
        processing a request for a Subscription, a server SHOULD validate that all requested filters are
        defined in the requested topic and are implemented in the server.

        The test will pass if the server either
        1. rejects the Subscription by responding with a non-201 response, or
        2. updates the Subscription resource to remove or replace the unsupported value.
      )

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@9'

      input :subscription_resource,
            title: 'Workflow Subscription Resource',
            type: 'textarea',
            description: %(
              A Subscription resource in JSON format that Inferno will send to the server under test
              so that it can demonstrate its ability to perform the Subscription creation and Notification
              response workflow. The instance must be conformant to the R4/B Topic-Based Subscription profile.
              Inferno may modify the Subscription before submission, e.g., to point to Inferno's notification endpoint.
              This input is also used by the unsupported Subscription test as the base on which to add unsupported
              element values to test for server rejection.
            )
      input :unsupported_subscription_filter,
            title: 'Unsupported Subscription Filter',
            description: %(A value for `filterCriteria` extension under the `criteria` that is not implemented by the
                           server to test for Subscription rejection.),
            optional: true

      run do
        assert_valid_json(subscription_resource)
        subscription = JSON.parse(subscription_resource)

        unsupported_info = {
          'unsupported_title' => 'unsupported filter criteria',
          'field_path' => ['_criteria'],
          'field_value' => if unsupported_subscription_filter.nil?
                             unsupported_subscription_filter
                           else
                             { 'extension' => [{
                               url: 'http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/backport-filter-criteria',
                               valueString: unsupported_subscription_filter
                             }] }
                           end
        }

        skip_if(unsupported_info['field_value'].blank?, %(
          No subscription filter input provided.))

        field_name = unsupported_info['field_path'].last

        outer_field_name = unsupported_info['field_path'].first
        subscription_field = if unsupported_info['field_path'].length > 1
                               subscription[outer_field_name]
                             else
                               subscription
                             end

        subscription_field[field_name] = unsupported_info['field_value']

        send_unsupported_subscription(subscription, unsupported_info['unsupported_title'],
                                      [unsupported_info['field_path']], [unsupported_info['field_value']])

        no_error_verification('Unsupported Subscription creation error handling failures.')
      end
    end
  end
end
