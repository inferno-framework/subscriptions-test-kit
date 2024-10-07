require_relative '../../../../common/notification_conformance_verification'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class NotificationConformanceTest < Inferno::Test
      include NotificationConformanceVerification

      id :subscriptions_r5_backport_r4_server_notification_conformance
      title 'Subscription Notification Verification'
      description %(
        As described in [Topic-Based Subscription Components](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/components.html#subscription-notifications),
        all notifications are enclosed in a Bundle with the type of history. Additionally, the first entry of the bundle
        SHALL be the SubscriptionStatus information, encoded as a Parameters resource using the
        [Backport SubscriptionStatus Profile](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription-status-r4.html)
        in FHIR R4.

        This test takes the received notification bundle and ensures it is conformant to the
        [R4 Topic-Based Subscription Notification Bundle](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription-notification-r4.html)
        profle.
      )

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@14',
                            'hl7.fhir.uv.subscriptions_1.1.0@15',
                            'hl7.fhir.uv.subscriptions_1.1.0@28',
                            'hl7.fhir.uv.subscriptions_1.1.0@69',
                            'hl7.fhir.uv.subscriptions_1.1.0@70',
                            'hl7.fhir.uv.subscriptions_1.1.0@138',
                            'hl7.fhir.uv.subscriptions_1.1.0@139'

      def subscription_type
        config.options[:subscription_type]
      end

      run do
        if subscription_type.present?
          requests = load_tagged_requests('subscription_creation', subscription_type)
          subscription_requests =
            requests
              .select { |request| request.status == 201 }
          skip_if subscription_requests.empty?,
                  'No successful Subscription creation request was made in the previous test.'
        else
          all_requests = load_tagged_requests('subscription_creation')
          all_subscription_requests =
            all_requests
              .select { |request| request.status == 201 }
          skip_if all_subscription_requests.empty?,
                  'No successful Subscription creation request was made in the previous test.'
          subscription_requests = [all_subscription_requests.first]
        end

        subscription_requests.each do |subscription_request|
          assert_valid_json(subscription_request.response_body)
          subscription = JSON.parse(subscription_request.response_body)

          requests = load_tagged_requests('event-notification', subscription['id'])
          skip_if requests.empty?, 'No event-notification requests were made in a previous test as expected.'

          requests = requests.uniq(&:request_body)
          requests.each do |request|
            notification_verification(
              request.request_body,
              'event-notification',
              subscription_id: subscription['id'],
              status: 'active'
            )
          end
        end
        no_error_verification('Received event-notifications are not conformant.')
      end
    end
  end
end
