require_relative '../../../../common/notification_conformance_verification'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class HandshakeConformanceTest < Inferno::Test
      include NotificationConformanceVerification

      id :subscriptions_r4_server_handshake_conformance
      title 'Subscription Handshake Verification'
      description %(
        When a Subscription is created for a REST Hook channel type, the server SHALL set initial status to requested,
        pending verification of the nominated endpoint URL. The Server will then send a handshake bundle to the endpoint.
        After a successful handshake notification has been sent and accepted, the server SHALL update the status to
        active. This test verifies that the incoming handshake request is a conformant
        [R4 Topic-Based Subscription Notification Bundle](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription-notification-r4.html).
      )

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@14',
                            'hl7.fhir.uv.subscriptions_1.1.0@15',
                            'hl7.fhir.uv.subscriptions_1.1.0@28',
                            'hl7.fhir.uv.subscriptions_1.1.0@69',
                            'hl7.fhir.uv.subscriptions_1.1.0@70',
                            'hl7.fhir.uv.subscriptions_1.1.0@24',
                            'hl7.fhir.uv.subscriptions_1.1.0@25',
                            'hl7.fhir.uv.subscriptions_1.1.0@138',
                            'hl7.fhir.uv.subscriptions_1.1.0@139'

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
            .select { |subscription| subscription['channel']['type'] == 'rest-hook' }
            .map { |subscription| subscription['id'] }

        requests = load_tagged_requests('handshake')
        if requests.empty?
          omit_if subscription_request_ids.empty?, 'No handshake requests were required or received in a previous tests.'
          assert(subscription_request_ids.empty?,
                'Handshake requests are required if a Subscription channel type is `rest-hook`')
        end

        requests = requests.uniq(&:request_body)

        requests.each do |request|
          tags = request.tags.dup
          tags -= ['handshake']
          subscription_id = tags.first

          subscription_request_ids.delete(subscription_id)

          notification_verification(request.request_body, 'handshake', subscription_id:, status: 'requested')
        end

        no_error_verification('Received handshakes are not conformant.')
        assert(subscription_request_ids.empty?,
              'Did not receive a handshake notification for some `rest-hook` subscriptions')
      end
    end
  end
end
