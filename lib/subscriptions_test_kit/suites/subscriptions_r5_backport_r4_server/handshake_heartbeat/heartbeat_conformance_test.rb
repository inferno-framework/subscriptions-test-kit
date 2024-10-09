require_relative '../../../common/notification_conformance_verification'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class HeartbeatConformanceTest < Inferno::Test
      include NotificationConformanceVerification

      id :subscriptions_r4_server_heartbeat_conformance
      title 'Subscription Heartbeat Verification'
      description %(
        When a Subscription is created for a REST Hook channel type, the server Server may send notifications of type
        heartbeat at any time. This test verifies that the incoming heartbeat request is a conformant
        [R4 Topic-Based Subscription Notification Bundle](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription-notification-r4.html).
      )

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@14',
                            'hl7.fhir.uv.subscriptions_1.1.0@15',
                            'hl7.fhir.uv.subscriptions_1.1.0@28',
                            'hl7.fhir.uv.subscriptions_1.1.0@69',
                            'hl7.fhir.uv.subscriptions_1.1.0@70',
                            'hl7.fhir.uv.subscriptions_1.1.0@138',
                            'hl7.fhir.uv.subscriptions_1.1.0@139',
                            'hl7.fhir.uv.subscriptions_1.1.0@93',
                            'hl7.fhir.uv.subscriptions_1.1.0@94'

      def heartbeat_period?(subscription_extensions)
        return false if subscription_extensions.blank?

        heartbeat = subscription_extensions.find do |extension|
          extension['url'].ends_with?('/backport-heartbeat-period')
        end

        return false if heartbeat.blank?

        heartbeat['valueUnsignedInt'].present?
      end

      run do
        subscription_requests = load_tagged_requests('subscription_creation')
        skip_if(subscription_requests.empty?, %(
          No Subscription creation requests were made in previous tests. Must run Subscription Workflow tests first in
          order to run this test.))

        subscription_request_ids =
          subscription_requests
            .select { |request| request.status == 201 }
            .uniq(&:response_body)
            .map { |request| JSON.parse(request.response_body) }
            .select { |subscription| heartbeat_period?(subscription['channel']['extension']) }
            .map { |subscription| subscription['id'] }

        requests = load_tagged_requests('heartbeat')
        if requests.empty?
          omit_if subscription_request_ids.empty?, 'No heartbeat requests requested or received in previous tests.'
          assert(subscription_request_ids.empty?, %(
              No Heartbeat notifications received when heartbeat was requested by the subscriber (`heartbeatPeriod` is
              populated)))
        end

        requests = requests.uniq(&:request_body)

        requests.each do |request|
          tags = request.tags.dup
          tags -= ['heartbeat']
          subscription_id = tags.first

          assert(subscription_request_ids.include?(subscription_id),
                 'If `heartbeatPeriod` field is not present in the Subscription, heartbeat should not be sent.')

          notification_verification(request.request_body, 'heartbeat', subscription_id:)
          no_error_verification('Received heartbeats are not conformant.')
        end
      end
    end
  end
end
