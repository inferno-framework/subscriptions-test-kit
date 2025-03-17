require_relative '../common/interaction_group'
require_relative '../common/interaction_verification_group'
require_relative 'id_only_content/id_only_conformance_test'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class IdOnlyContentGroup < Inferno::TestGroup
      id :subscriptions_r4_server_id_only_content
      title 'Id Only Notification Verification'
      description %(
        Verify that the received Notifications are conformant to the
        [R4 Topic-Based Subscription Notification Bundle](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription-notification-r4.html)
        profile, including additional requirements around the `id-only` content type ([example id-only
        Subscription](https://github.com/inferno-framework/subscriptions-test-kit/blob/main/lib/subscriptions_test_kit/docs/samples/Subscription_id-only.json)).
      )
      run_as_group
      optional

      input_order :url, :smart_auth_info, :access_token, :id_only_subscription_resource

      group from: :subscriptions_r4_server_interaction do
        id :subscriptions_r4_server_id_only_content_interaction
        optional

        config(
          options: { subscription_type: 'id-only' },
          inputs: {
            subscription_resource: {
              name: :id_only_subscription_resource,
              title: 'Id-Only Notification Subscription Resource',
              type: 'textarea',
              description: %(
                A Subscription resource in JSON format that Inferno will send to the server under test
                so that it can demonstrate its ability to send an id-only Notification.
                The instance must be conformant to the R4/B Topic-Based Subscription profile.
                Inferno may modify the Subscription before submission, e.g., to point to Inferno's notification
                endpoint.
            ),
              optional: true
            },
            updated_subscription: { name: :id_only_updated_subscription }
          },
          outputs: {
            updated_subscription: { name: :id_only_updated_subscription }
          }
        )
      end
      group from: :subscriptions_r4_server_interaction_verification do
        id :subscriptions_r4_server_id_only_content_interaction_verification
        optional

        config(
          options: { subscription_type: 'id-only' }
        )
        test from: :subscriptions_r4_server_id_only_conformance
      end
    end
  end
end
