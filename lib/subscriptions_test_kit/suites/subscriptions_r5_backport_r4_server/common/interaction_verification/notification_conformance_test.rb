require_relative '../../../../common/notification_conformance_verification'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class NotificationConformanceTest < Inferno::Test
      include NotificationConformanceVerification

      id :subscriptions_r4_server_notification_conformance
      title 'Subscription Event Notification Verification'
      description %(
        As described in [Topic-Based Subscription Components](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/components.html#subscription-notifications),
        all notifications are enclosed in a Bundle with the type of history. Additionally, the first entry of the bundle
        SHALL be the SubscriptionStatus information, encoded as a Parameters resource using the
        [Backport SubscriptionStatus Profile](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription-status-r4.html)
        in FHIR R4.

        This test takes the received event notification bundle or bundles from the most recently successfully created
        Subscription (from the just-run interaction test) and ensures they are conformant to the
        [R4 Topic-Based Subscription Notification Bundle](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription-notification-r4.html)
        profle. Note that other interactions like handshake and heartbeat notification are not verified as a
        part of this test and those requests will not be associated with this test.
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
          skip_if subscription_requests.empty?, %(
                    No successful Subscription creation request of type #{subscription_type}
                    was made in the previous test.
                  )
        else
          all_requests = load_tagged_requests('subscription_creation')
          subscription_requests =
            all_requests
              .select { |request| request.status == 201 }
          skip_if subscription_requests.empty?,
                  'No successful Subscription creation request was made in the previous test.'
        end

        # select the most recent subscription to verify
        # this test is run as part of the interaction group, so the most recent
        # successfully created Subscription will be the one that came during
        # the previoius interaction test
        latest_subscription = nil
        subscription_requests.each do |subscription_request|
          if latest_subscription.blank? || latest_subscription.created_at < subscription_request.created_at
            latest_subscription = subscription_request
          end
        end

        assert_valid_json(latest_subscription.response_body)
        subscription = JSON.parse(latest_subscription.response_body)

        requests = load_tagged_requests('event-notification', subscription['id'])
        skip_if requests.empty?, %(
                  No event-notification requests were made for Subscription #{subscription['id']}
                  in during the interaction.
                )

        requests = requests.uniq(&:request_body)
        requests.each do |request|
          notification_verification(
            request.request_body,
            'event-notification',
            subscription_id: subscription['id'],
            status: 'active'
          )
        end

        no_error_verification("Received event-notifications for Subscription #{subscription['id']} are not conformant.")
      end
    end
  end
end
