require_relative '../common/subscription_creation'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class RejectSubscriptionTopicTest < Inferno::Test
      include SubscriptionCreation

      id :subscriptions_r4_server_reject_subscription_topic
      title 'Server Handles Unsupported Subscription Topics'
      description %(
        When processing a request for a Subscription a server SHOULD verify that the Subscription is supported and does
        not contain any information not implemented by the server. If the Subscription is no supported, the server
        should reject the Subscription create request, or it should attempt to adjust the Subscription. When processing a
        request for a Subscription, a server SHOULD validate that the SubscriptionTopic is valid and implemented by the server.

        The test will pass if the server either
        1. rejects the Subscription by responding with a non-201 response, or
        2. updates the Subscription resource to remove or replace the unsupported value.
      )

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@8'

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
      input :unsupported_subscription_topic,
            title: 'Unsupported Subscription Topic',
            description: %(A Subscription Topic for the `criteria` element that is not implemented by the server to test
                           for Subscription rejection.),
            optional: true

      run do
        assert_valid_json(subscription_resource)
        subscription = JSON.parse(subscription_resource)

        unsupported_info = {
          'unsupported_title' => 'unsupported `SubscriptionTopic`',
          'field_path' => ['criteria'],
          'field_value' => unsupported_subscription_topic
        }

        skip_if(unsupported_info['field_value'].blank?, %(
          No subscription topic input provided.))

        field_name = unsupported_info['field_path'].last

        outer_field_name = unsupported_info['field_path'].first
        subscription_field = unsupported_info['field_path'].length > 1 ?
                    subscription[outer_field_name] :
                    subscription

        subscription_field[field_name] = unsupported_info['field_value']

        send_unsupported_subscription(subscription, unsupported_info['unsupported_title'],
                                        [unsupported_info['field_path']], [unsupported_info['field_value']])

        no_error_verification('Unsupported Subscription creation error handling failures.')
      end
    end
  end
end
