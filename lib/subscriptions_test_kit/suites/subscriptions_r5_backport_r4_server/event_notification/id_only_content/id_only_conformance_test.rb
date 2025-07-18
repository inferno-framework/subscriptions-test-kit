require_relative '../../../../common/notification_conformance_verification'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class IdOnlyConformanceTest < Inferno::Test
      include NotificationConformanceVerification

      id :subscriptions_r4_server_id_only_conformance
      title 'Subscription Id-Only Notification Verification'
      description %(
        This test takes the received notification bundle and ensures it is conformant to the
        [R4 Topic-Based Subscription Notification Bundle](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription-notification-r4.html)
        profle.

        With the content type of id-only, the resources involved in triggering the notification are only available
        through other channels, but notifications include URLs which can be used to access those resources.

        When the content type is id-only, notification bundles SHALL include references to the appropriate focus
        resources in the SubscriptionStatus.notificationEvent.focus element.

        Additionally, notification bundles MAY contain, in addition to the SubscriptionStatus used to convey status
        information, at least one Bundle.entry for each resource relevant to the notification.

        Each Bundle.entry for id-only notification SHALL contain a relevant resource URL in the fullUrl and request
        elements, as is required for history bundles.
      )

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@14',
                            'hl7.fhir.uv.subscriptions_1.1.0@15',
                            'hl7.fhir.uv.subscriptions_1.1.0@28',
                            'hl7.fhir.uv.subscriptions_1.1.0@69',
                            'hl7.fhir.uv.subscriptions_1.1.0@70',
                            'hl7.fhir.uv.subscriptions_1.1.0@40',
                            'hl7.fhir.uv.subscriptions_1.1.0@42',
                            'hl7.fhir.uv.subscriptions_1.1.0@35',
                            'hl7.fhir.uv.subscriptions_1.1.0@67',
                            'hl7.fhir.uv.subscriptions_1.1.0@51',
                            'hl7.fhir.uv.subscriptions_1.1.0@53',
                            'hl7.fhir.uv.subscriptions_1.1.0@65',
                            'hl7.fhir.uv.subscriptions_1.1.0@100',
                            'hl7.fhir.uv.subscriptions_1.1.0@138',
                            'hl7.fhir.uv.subscriptions_1.1.0@139'

      run do
        # binding.pry # DEBUGGING

        subscription_requests = load_tagged_requests('subscription_creation', 'id-only')
        omit_if subscription_requests.empty?, 'No Subscriptions sent with notification payload type of `id-only`'

        subscription_requests.each do |subscription_request|
          assert_valid_json(subscription_request.response_body)
          subscription = JSON.parse(subscription_request.response_body)

          requests = load_tagged_requests('event-notification', subscription['id'])
          skip_if requests.empty?, 'No event-notification requests were made in a previous test as expected.'

          requests = requests.uniq(&:request_body)

          requests.each do |request|
            id_only_event_notification_verification(request.request_body, nil)
          end
        end
        no_error_verification('Received notification-events are not conformant.')
      end
    end
  end
end
