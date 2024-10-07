require_relative '../../common/subscription_creation'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class RejectSubscriptionsTest < Inferno::Test
      include SubscriptionCreation

      id :subscriptions_r5_backport_r4_server_reject_subscriptions
      title 'Server Handles Unsupported Subscriptions'
      description %(
        When processing a request for a Subscription a server SHOULD verify that the Subscription is supported and does not
        contain any information not implemented by the server. If the Subscription is no supported, the server should reject
        the Subscription create request, or it should attempt to adjust the Subscription. This test checks that the server
        correctly rejects or adjusts the Subscription in the following cases:

          - The Subscription contains cross-version extension
          - The Subscription contains a Subscription Topic not implemented by the server
          - The Subscription contains a filtering criteria not implemented by the server
          - The Subscription contains channel type not implemented by the server
          - The Subscription contains an unsupported channel endpoint
          - The Subscription contains a payload type not implemented by the server
          - The Subscription contains an unsupported channel and payload type combination

        The test will pass if the server either 
        1. rejects the Subscription by responding with a non-201 response, or
        2. updates the Subscription resource to remove or replace the unsupported value.
      )

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@8',
                            'hl7.fhir.uv.subscriptions_1.1.0@9',
                            'hl7.fhir.uv.subscriptions_1.1.0@10',
                            'hl7.fhir.uv.subscriptions_1.1.0@11',
                            'hl7.fhir.uv.subscriptions_1.1.0@12',
                            'hl7.fhir.uv.subscriptions_1.1.0@13'

      input :subscription_resource,
            title: 'Workflow Subscription Resource',
            type: 'textarea',
            description: %(
              A Subscription resource in JSON format that Inferno will send to the server under test
              so that it can demonstrate its ability to perform the Subscription creation and Notification
              response workflow. The instance must be conformant to the R4/B Topic-Based Subscription profile.
              Inferno may modify the Subscription before submission, e.g., to point to Inferno's notification endpoint.
              This input is also used by the unsupported Subscription test as the base on which to add unsupported element
              values to test for server rejection.
            )
      input :unsupported_subscription_topic,
            title: 'Unsupported Subscription Topic',
            description: 'A Subscription Topic for the `criteria` element that is not implemented by the server to test for Subscription rejection.',
            optional: true
      input :unsupported_subscription_filter,
            title: 'Unsupported Subscription Filter',
            description: 'A value for `filterCriteria` extension under the `criteria` that is not implemented by the server to test for Subscription rejection.',
            optional: true
      input :unsupported_subscription_channel_type,
            title: 'Unsupported Subscription Channel Type',
            description: 'A value for the `channel.type` element that is not implemented by the server to test for Subscription rejection.',
            optional: true
      input :unsupported_subscription_channel_endpoint,
            title: 'Unsupported Subscription Channel Endpoint',
            description: 'An unsupported value for the `channel.endpoint` element to test for Subscription rejection.',
            optional: true
      input :unsupported_subscription_payload_type,
            title: 'Unsupported Subscription Payload Type',
            description: 'A value for the `content` extension under the `channel.payload` element that is not implemented by the server to test for Subscription rejection.',
            optional: true
      input :unsupported_subscription_channel_payload_combo,
            title: 'Unsupported Subscription Channel and Payload Combination',
            description: %(
              A channel (`channel.type`) and payload type (`content` extension under the `channel.payload` element) 
              combination not implemented by the server to test for Subscription
              rejection. Provide in the json format e.g. {channel: <'channel_type'>, payload: <'payload_type'>}.
            ),
            optional: true

      def unsupported_subscriptions
        [
          {
            'unsupported_title' => 'cross-version extensions',
            'field_path' => ['_criteria'],
            'field_value' => { 'extension' => [{
              url: 'http://hl7.org/fhir/5.0/subscriptions-backport/StructureDefinition/backport-filter-criteria',
              valueString: 'Encounter?patient=Patient/123'
            }] }
          },
          {
            'unsupported_title' => 'unsupported `SubscriptionTopic`',
            'field_path' => ['criteria'],
            'field_value' => unsupported_subscription_topic
          },
          {
            'unsupported_title' => 'unsupported filter criteria',
            'field_path' => ['_criteria'],
            'field_value' => if unsupported_subscription_filter.nil?
                              unsupported_subscription_filter
                            else
                              { 'extension' => [{
                                url: 'http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/backport-filter-criteria',
                                valueString: unsupported_subscription_filter
                              }] }
                            end
          },
          {
            'unsupported_title' => 'unsupported channel type',
            'field_path' => ['channel', 'type'],
            'field_value' => unsupported_subscription_channel_type
          },
          {
            'unsupported_title' => 'unsupported channel URL',
            'field_path' => ['channel', 'endpoint'],
            'field_value' => unsupported_subscription_channel_endpoint
          },
          {
            'unsupported_title' => 'unsupported channel type',
            'field_path' => ['channel', 'type'],
            'field_value' => unsupported_subscription_channel_type
          },
          {
            'unsupported_title' => 'unsupported payload type',
            'field_path' => ['channel', 'payload'],
            'field_value' => unsupported_subscription_payload_type
          }
        ]
      end

      run do
        assert_valid_json(subscription_resource)
        subscription = JSON.parse(subscription_resource)

        unsupported_subscriptions.each do |unsupported_info|
          next if unsupported_info['field_value'].blank?

          field_name = unsupported_info['field_path'].last

          if unsupported_info['field_path'].length > 1
            outer_field_name = unsupported_info['field_path'].first
            subscription_field = subscription[outer_field_name]
          else
            subscription_field = subscription
          end

          original_field_value = subscription_field[field_name]
          subscription_field[field_name] = unsupported_info['field_value']

          send_unsupported_subscription(subscription, unsupported_info['unsupported_title'], [unsupported_info['field_path']],
                                    [unsupported_info['field_value']])

          if original_field_value.nil?
            subscription_field.delete(field_name)
          else
            subscription_field[field_name] = original_field_value
          end
        end

        if unsupported_subscription_channel_payload_combo.present?
          assert_valid_json(unsupported_subscription_channel_payload_combo)
          channel_payload_combo = JSON.parse(unsupported_subscription_channel_payload_combo)
          channel_value = channel_payload_combo['channel']
          payload_value = channel_payload_combo['payload']

          if channel_value.blank? || payload_value.blank?
            add_message('error', %(
                Channel and payload values are not populated correctly in unsupported channel and payload combination input.))
          else
            subscription_channel = subscription['channel']
            subscription_channel['type'] = channel_value
            subscription_channel['payload'] = payload_value

            channel_path = ['channel', 'type']
            payload_path = ['channel', 'payload']

            send_unsupported_subscription(subscription, 'unsupported channel and payload combination', [channel_path, payload_path],
                                      [channel_value, payload_value])
          end
        end

        no_error_verification('Unsupported Subscription creation error handling failures.')
      end
    end
  end
end
