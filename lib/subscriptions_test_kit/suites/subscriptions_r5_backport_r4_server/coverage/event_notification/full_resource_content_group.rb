require_relative '../../common/interaction_group'
require_relative '../../common/interaction_verification_group'
require_relative 'full_resource_content/full_resource_conformance_test'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class FullResourceContentGroup < Inferno::TestGroup
      id :subscriptions_r5_backport_r4_server_full_resource_content
      title 'Full Resource Notification Verification'
      description %(
        Verify that the received Notifications are conformant to the
        [R4 Topic-Based Subscription Notification Bundle](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription-notification-r4.html)
        profile, including additional requirements around the `full-resource` content type ([example full-resource
        Subscription](https://github.com/inferno-framework/subscriptions-test-kit/blob/main/subscriptions_test_kit/docs/samples/Subscription_full-resource.json)).
      )
      run_as_group
      optional

      input_order :url, :credentials, :access_token, :full_resource_subscription_resource

      group from: :subscriptions_r5_backport_r4_server_interaction do
        id :subscriptions_r5_backport_r4_server_full_resource_content_interaction
        optional

        config(
          options: { subscription_type: 'full-resource' },
          inputs: {
            subscription_resource: {
              name: :full_resource_subscription_resource,
              title: 'Full-Resource Notification Subscription Resource',
              type: 'textarea',
              description: %(
                A Subscription resource in JSON format that Inferno will send to the server under test
                so that it can demonstrate its ability to send a full-resource Notification. 
                The instance must be conformant to the R4/B Topic-Based Subscription profile.
                Inferno may modify the Subscription before submission, e.g., to point to Inferno's notification endpoint.
            ),
              optional: true
            },
            updated_subscription: { name: :full_resource_updated_subscription }
          },
          outputs: {
            updated_subscription: { name: :full_resource_updated_subscription }
          }
        )
      end
      group from: :subscriptions_r5_backport_r4_server_interaction_verification do
        id :subscriptions_r5_backport_r4_server_full_resource_content_interaction_verification
        optional

        config(
          options: { subscription_type: 'full-resource' }
        )
        test from: :subscriptions_r5_backport_r4_server_full_resource_conformance
      end
    end
  end
end
