require_relative '../../../../../common/notification_conformance_verification'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class FullResourceConformanceTest < Inferno::Test
      include NotificationConformanceVerification

      id :subscriptions_r4_server_full_resource_conformance
      title 'Subscription Full-Resource Notification Verification'
      description %(
        This test takes the received notification bundle and ensures it is conformant to the
        [R4 Topic-Based Subscription Notification Bundle](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription-notification-r4.html)
        profle.

        With the content type of full-resource, the resources involved in triggering the notification are included in the
        notification bundle.

        When the content type is full-resource, notification bundles SHALL include references to the
        appropriate focus resources in the SubscriptionStatus.notificationEvent.focus element.

        Notification bundles for full-resource subscriptions SHALL contain, in addition to the SubscriptionStatus, at
        least one Bundle.entry for each resource relevant to the notification.

        Each Bundle.entry for a full-resource notification SHALL contain a relevant resource in the
        entry.resource element. If a server cannot include the resource contents due to an issue with a specific
        notification, the server SHALL populate the entry.request and/or entry.response elements.
      )

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@14',
                            'hl7.fhir.uv.subscriptions_1.1.0@15',
                            'hl7.fhir.uv.subscriptions_1.1.0@28',
                            'hl7.fhir.uv.subscriptions_1.1.0@69',
                            'hl7.fhir.uv.subscriptions_1.1.0@70',
                            'hl7.fhir.uv.subscriptions_1.1.0@43',
                            'hl7.fhir.uv.subscriptions_1.1.0@44',
                            'hl7.fhir.uv.subscriptions_1.1.0@45',
                            'hl7.fhir.uv.subscriptions_1.1.0@35',
                            'hl7.fhir.uv.subscriptions_1.1.0@67',
                            'hl7.fhir.uv.subscriptions_1.1.0@51',
                            'hl7.fhir.uv.subscriptions_1.1.0@53',
                            'hl7.fhir.uv.subscriptions_1.1.0@65',
                            'hl7.fhir.uv.subscriptions_1.1.0@101',
                            'hl7.fhir.uv.subscriptions_1.1.0@138',
                            'hl7.fhir.uv.subscriptions_1.1.0@139'

      run do
        subscription_requests = load_tagged_requests('subscription_creation', 'full-resource')
        omit_if subscription_requests.empty?, 'No Subscriptions sent with notification payload type of `full-resource`'

        subscription_requests.each do |subscription_request|
          assert_valid_json(subscription_request.response_body)
          subscription = JSON.parse(subscription_request.response_body)

          requests = load_tagged_requests('event-notification', subscription['id'])
          skip_if requests.empty?, 'No event-notification requests were made in a previous test as expected.'

          criteria_resource_type = subscription_criteria(subscription)
          requests = requests.uniq(&:request_body)

          requests.each do |request|
            full_resource_event_notification_verification(request.request_body, criteria_resource_type)
          end
        end
        no_error_verification('Received notification-events are not conformant.')
      end
    end
  end
end
