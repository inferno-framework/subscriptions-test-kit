# frozen_string_literal: true

require_relative '../../../../common/subscription_conformance_verification'
require_relative '../../../../common/notification_conformance_verification'
require_relative '../../common/subscription_simulation_utils'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class NotificationInputPayloadVerificationTest < Inferno::Test
      include NotificationConformanceVerification
      include SubscriptionConformanceVerification
      include SubscriptionSimulationUtils

      id :subscriptions_r4_client_notification_input_payload_verification
      title '[USER INPUT VERIFICATION] Notification Bundle Input Conformance Verification for Payload Content'
      description 'This test verifies that the notification bundle from the test input meets the requirements ' \
                  'of the payload indicated in the subscription created by the client under test.'
      input :notification_bundle

      run do
        subscription = find_subscription(test_session_id)
        skip_if(subscription.nil?, 'No subscription found for this test run')

        # Payload content type is a primitive extension, so we have to parse the source hash
        channel_hash = subscription.channel&.source_hash
        payload_exts = channel_hash&.dig('_payload', 'extension')
        payload_ext = payload_exts&.find do |e|
          e['url'] == 'http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/backport-payload-content'
        end
        payload_content_code = payload_ext['valueCode'] if payload_ext
        skip_if(payload_content_code.nil?, 'Subscription does not have a payload content code')

        criteria_resource_type = subscription_criteria(subscription.source_hash)

        case payload_content_code
        when 'empty'
          empty_event_notification_verification(notification_bundle)
        when 'id-only'
          id_only_event_notification_verification(notification_bundle, criteria_resource_type)
        when 'full-resource'
          full_resource_event_notification_verification(notification_bundle, criteria_resource_type)
        else
          skip "Unrecognized payload content code: #{payload_content_code}"
        end

        no_error_verification('Notification bundle input payload content was not conformant, see error messages')
      end
    end
  end
end
