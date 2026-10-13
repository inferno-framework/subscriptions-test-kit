require_relative 'subscriptions_r5_backport_r4_server/workflow_group'
require_relative 'subscriptions_r5_backport_r4_server/capability_statement_group'
require_relative 'subscriptions_r5_backport_r4_server/event_notification_group'
require_relative 'subscriptions_r5_backport_r4_server/handshake_heartbeat_group'
require_relative 'subscriptions_r5_backport_r4_server/status_operation_group'
require_relative 'subscriptions_r5_backport_r4_server/subscription_rejection_group'
require_relative 'subscriptions_r5_backport_r4_server/update_delete_group'
require_relative '../endpoints/subscription_rest_hook_endpoint'
require_relative '../fhir_validation'
require_relative '../urls'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class SubscriptionsR5BackportR4ServerSuite < Inferno::TestSuite
      id :subscriptions_r5_backport_r4_server
      title 'Subscriptions R5 Backport IG v1.1.0 FHIR R4 Server Test Suite'
      short_title 'Subscriptions R4 Server'
      description File.read(File.join(__dir__, '..', 'docs',
                                      'subscriptions_r5_backport_r4_server_suite_description.md'))

      links [
        {
          label: 'Report Issue',
          url: 'https://github.com/inferno-framework/subscriptions-test-kit/issues'
        },
        {
          label: 'Open Source',
          url: 'https://github.com/inferno-framework/subscriptions-test-kit'
        },
        {
          label: 'Download',
          url: 'https://github.com/inferno-framework/subscriptions-test-kit/releases'
        },
        {
          label: 'Implementation Guide',
          url: 'https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/'
        }
      ]

      requirement_sets(
        {
          identifier: 'hl7.fhir.uv.subscriptions_1.1.0',
          title: 'Subscriptions R5 Backport IG',
          actor: 'Server'
        }
      )

      # These inputs will be available to all tests in this suite
      input :url,
            title: 'FHIR Server Base URL',
            description: %(
                            FHIR base URL for the server under test where Inferno will send
                            Subscription Creation, $status, and other requests as a part of
                            these tests.
                          )

      input :smart_auth_info,
            title: 'OAuth Credentials',
            description: 'Credentials for Inferno to include when making requests against the server under test.',
            type: :auth_info,
            optional: true,
            options: {
              mode: 'access'
            }

      # All FHIR requests in this suite will use this FHIR client
      fhir_client do
        url :url
        auth_info :smart_auth_info
      end

      # All FHIR validation requests will use this FHIR validator
      fhir_resource_validator do
        igs SUBSCRIPTIONS_BACKPORT_IG

        exclude_message do |message|
          message.message.match?(UNRESOLVED_URL_VALIDATION_MESSAGE)
        end
      end

      # Used to validate tester-provided content so that it cannot rely on extensions not defined in the IG
      fhir_resource_validator :no_custom_extensions do
        igs SUBSCRIPTIONS_BACKPORT_IG

        validation_context do
          extensions [] # no extensions not in the spec
        end

        exclude_message do |message|
          message.message.match?(UNRESOLVED_URL_VALIDATION_MESSAGE)
        end
      end

      def self.extract_token_from_query_params(request)
        request.query_parameters['token']
      end

      suite_endpoint :post, SUBSCRIPTION_CHANNEL_PATH, SubscriptionRestHookEndpoint

      resume_test_route :get, RESUME_PASS_PATH do |request|
        SubscriptionsR5BackportR4ServerSuite.extract_token_from_query_params(request)
      end

      group from: :subscriptions_r4_server_workflow
      group from: :subscriptions_r4_server_capability_statement
      group from: :subscriptions_r4_server_event_notification
      group from: :subscriptions_r4_server_handshake_heartbeat
      group from: :subscriptions_r4_server_status_operation
      group from: :subscriptions_r4_server_subscription_rejection
      group from: :subscriptions_r4_server_update_delete
    end
  end
end
