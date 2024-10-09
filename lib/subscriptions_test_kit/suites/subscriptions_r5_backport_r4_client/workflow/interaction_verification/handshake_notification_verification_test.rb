# frozen_string_literal: true

require_relative '../../common/subscription_simulation_utils'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class HandshakeNotificationVerificationTest < Inferno::Test
      include SubscriptionSimulationUtils

      id :subscriptions_r4_client_handshake_notification_verification
      title 'Rest-Hook Handshake Notification Verification'
      description %(
        This test verifies that the client's response to the handshake notification
        was conformant.
      )
      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@71'

      run do
        load_tagged_requests(REST_HOOK_HANDSHAKE_NOTIFICATION_TAG)
        skip_if(requests.none?, 'Inferno did not send a handshake notification')

        # The SendSubscriptionNotifications job saves a nil status if the request fails entirely
        assert(request.status.present?, "Handshake notification request failed with error: #{request.response_body}")

        assert(request.status.between?(200, 299),
               "Handshake notification was not successful, status code #{request.status}")

        subscription = find_subscription(test_session_id)
        if subscription.present?
          mime_type = subscription&.channel&.payload
          unless ALLOWED_MIME_TYPES.include?(mime_type)
            add_message('warning', %(Subscription specified '#{mime_type}' for `Subscription.channel.payload`, but Inferno
                                    only supports: #{ALLOWED_MIME_TYPES.map { |type| "'#{type}'" }.join(', ')}.
                                    Handshake notification was sent with Content-Type: '#{DEFAULT_MIME_TYPE}'.))
          end
        end
      end
    end
  end
end
