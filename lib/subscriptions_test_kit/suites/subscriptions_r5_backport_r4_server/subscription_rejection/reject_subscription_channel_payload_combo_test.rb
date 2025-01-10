require_relative '../common/subscription_creation'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class RejectSubscriptionChannelPayloadComboTest < Inferno::Test
      include SubscriptionCreation

      id :subscriptions_r4_server_reject_subscription_channel_payload_combo
      title 'Server Handles Unsupported Subscription Payload for Channel Type'
      description %(
        When processing a request for a Subscription a server SHOULD verify that the Subscription is supported and does
        not contain any information not implemented by the server. If the Subscription is not supported, the server
        should reject the Subscription create request, or it should attempt to adjust the Subscription. When
        processing a request for a Subscription, a server SHOULD validate, that the payload configuration is
        valid for the channel type requested (e.g., complies with the server's security policy).

        The test will pass if the server either
        1. rejects the Subscription by responding with a non-201 response, or
        2. updates the Subscription resource to remove or replace the unsupported value.
      )

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@13'

      input :subscription_resource,
            title: 'Workflow Subscription Resource',
            type: 'textarea',
            description: %(
              A Subscription resource in JSON format that Inferno will send to the server under test
              so that it can demonstrate its ability to perform the Subscription creation and Notification
              response workflow. The instance must be conformant to the R4/B Topic-Based Subscription profile.
              Inferno may modify the Subscription before submission, e.g., to point to Inferno's notification endpoint.
              This input is also used by the unsupported Subscription test as the base on which to add unsupported
              element values to test for server rejection.
            )
      input :unsupported_subscription_channel_payload_combo,
            title: 'Unsupported Subscription Channel and Payload Combination',
            description: %(
              A channel (`channel.type`) and payload type (`content` extension under the `channel.payload` element)
              combination not implemented by the server to test for Subscription
              rejection. Provide in the json format e.g. {channel: <'channel_type'>, payload: <'payload_type'>}.
            ),
            optional: true

      run do
        skip_if(unsupported_subscription_channel_payload_combo.blank?, %(
          No subscription channel type and payload combo provided.))

        assert_valid_json(subscription_resource)
        subscription = JSON.parse(subscription_resource)

        assert_valid_json(unsupported_subscription_channel_payload_combo)
        channel_payload_combo = JSON.parse(unsupported_subscription_channel_payload_combo)
        channel_value = channel_payload_combo['channel']
        payload_value = channel_payload_combo['payload']

        if channel_value.blank? || payload_value.blank?
          add_message('error', %(Channel and payload values are not populated correctly in unsupported channel and
                                 payload combination input.))
        else
          subscription_channel = subscription['channel']
          subscription_channel['type'] = channel_value
          subscription_channel['payload'] = payload_value

          channel_path = ['channel', 'type']
          payload_path = ['channel', 'payload']

          send_unsupported_subscription(subscription, 'unsupported channel and payload combination',
                                        [channel_path, payload_path], [channel_value, payload_value])
        end

        no_error_verification('Unsupported Subscription creation error handling failures.')
      end
    end
  end
end
