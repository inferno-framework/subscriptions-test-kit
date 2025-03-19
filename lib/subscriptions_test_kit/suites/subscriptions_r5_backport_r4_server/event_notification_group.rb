require_relative 'event_notification/empty_content_group'
require_relative 'event_notification/full_resource_content_group'
require_relative 'event_notification/id_only_content_group'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class EventNotificationGroup < Inferno::TestGroup
      id :subscriptions_r4_server_event_notification
      title 'Backport Subscription Notification Payload Type Verification'
      description %(
        Verify that the received Notifications are conformant to the
        [R4 Topic-Based Subscription Notification Bundle](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription-notification-r4.html)
        profile, including additional requirements around the payload type. This group contains tests for the three
        options available when specifying the content level for event notification payloads:
        `empty`, `id-only`, and `full-resource`.
      )

      input_order :url, :smart_auth_info, :access_token, :empty_subscription_resource,
                  :id_only_subscription_resource, :full_resource_subscription_resource

      group from: :subscriptions_r4_server_empty_content
      group from: :subscriptions_r4_server_id_only_content
      group from: :subscriptions_r4_server_full_resource_content
    end
  end
end
