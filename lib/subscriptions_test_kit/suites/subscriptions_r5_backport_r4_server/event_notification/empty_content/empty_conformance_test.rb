require_relative '../../../../common/notification_conformance_verification'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class EmptyConformanceTest < Inferno::Test
      include NotificationConformanceVerification

      id :subscriptions_r4_server_empty_conformance
      title 'Subscription Empty Notification Verification'
      description %(
        This test takes the received empty notification bundle and ensures it is conformant to the
        [R4 Topic-Based Subscription Notification Bundle](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription-notification-r4.html)
        profle and to the requirements listed for empty notifications.

        With the content type of empty, no information about the resources involved in triggering the notification is
        available via the subscription channel. When populating the SubscriptionStatus.notificationEvent structure for a
        notification with an empty payload, a server SHALL NOT include references to resources
        (e.g., SubscriptionStatus.notificationEvent.focus and SubscriptionStatus.notificationEvent.additionalContext
        SHALL NOT be present).

        When the content type is empty, notification bundles SHALL not contain Bundle.entry
        elements other than the SubscriptionStatus for the notification.
      )

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@14',
                            'hl7.fhir.uv.subscriptions_1.1.0@15',
                            'hl7.fhir.uv.subscriptions_1.1.0@28',
                            'hl7.fhir.uv.subscriptions_1.1.0@69',
                            'hl7.fhir.uv.subscriptions_1.1.0@70',
                            'hl7.fhir.uv.subscriptions_1.1.0@38',
                            'hl7.fhir.uv.subscriptions_1.1.0@39',
                            'hl7.fhir.uv.subscriptions_1.1.0@35',
                            'hl7.fhir.uv.subscriptions_1.1.0@67',
                            'hl7.fhir.uv.subscriptions_1.1.0@51',
                            'hl7.fhir.uv.subscriptions_1.1.0@53',
                            'hl7.fhir.uv.subscriptions_1.1.0@65',
                            'hl7.fhir.uv.subscriptions_1.1.0@99',
                            'hl7.fhir.uv.subscriptions_1.1.0@138',
                            'hl7.fhir.uv.subscriptions_1.1.0@139'

      run do
        subscription_requests = load_tagged_requests('subscription_creation', 'empty')
        omit_if subscription_requests.empty?, 'No Subscriptions sent with notification payload type of `empty`'

        subscription_requests.each do |subscription_request|
          assert_valid_json(subscription_request.response_body)
          subscription = JSON.parse(subscription_request.response_body)

          requests = load_tagged_requests('event-notification', subscription['id'])
          skip_if requests.empty?, 'No event-notification requests were made in a previous test as expected.'

          requests = requests.uniq(&:request_body)

          requests.each do |request|
            empty_event_notification_verification(request.request_body)
          end
        end

        no_error_verification('Received empty notification-events are not conformant.')
      end
    end
  end
end
