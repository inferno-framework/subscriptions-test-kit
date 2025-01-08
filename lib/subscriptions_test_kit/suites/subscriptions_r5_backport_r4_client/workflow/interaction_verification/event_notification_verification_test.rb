# frozen_string_literal: true

require_relative '../../common/subscription_simulation_utils'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class EventNotificationVerificationTest < Inferno::Test
      include SubscriptionSimulationUtils

      id :subscriptions_r4_client_event_notification_verification
      title 'Rest-Hook Event Notification Verification'
      description %(
        This test verifies that the client's response to the event notification
        was conformant.
      )
      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@24',
                            'hl7.fhir.uv.subscriptions_1.1.0@71'

      run do
        load_tagged_requests(REST_HOOK_EVENT_NOTIFICATION_TAG)
        skip_if(requests.none?, 'Inferno did not send an event notification')

        # The SendSubscriptionNotifications job saves a nil status if the request fails entirely
        assert(request.status.present?, "Handshake notification request failed with error: #{request.response_body}")

        assert(request.status.between?(200, 299),
               "Event notification was not successful, status code #{request.status}")

        subscription = find_subscription(test_session_id)
        if subscription.present?
          mime_type = subscription&.channel&.payload
          unless ALLOWED_MIME_TYPES.include?(mime_type)
            add_message('warning', %(Subscription specified '#{mime_type}' for `Subscription.channel.payload`, but
                                     Inferno only supports: #{ALLOWED_MIME_TYPES.map { |type| "'#{type}'" }.join(', ')}.
                                     Event notification was sent with Content-Type: '#{DEFAULT_MIME_TYPE}'.))
          end

          # Verification for hl7.fhir.uv.subscriptions_1.1.0@26
          assert(request.content_type_header == mime_type, 
                 'Content type of request does not match the Subscription MIME type')
          # Verification for hl7.fhir.uv.subscriptions_1.1.0@27
          assert(request.header.include?(subscription&.channel&.header), 
                 'Subscriptoin channel header is not conveyed as HTTP request header')

        end
      end
    end
  end
end
