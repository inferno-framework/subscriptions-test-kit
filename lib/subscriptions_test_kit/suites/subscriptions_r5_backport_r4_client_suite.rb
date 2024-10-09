# frozen_string_literal: true

require_relative 'subscriptions_r5_backport_r4_client/workflow_group'
require_relative '../endpoints/subscription_create_endpoint'
require_relative '../endpoints/subscription_read_endpoint'
require_relative '../endpoints/subscription_status_endpoint'
require_relative '../version'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class SubscriptionsR5BackportR4ClientSuite < Inferno::TestSuite
      id :subscriptions_r5_backport_r4_client
      title 'Subscriptions R5 Backport IG v1.1.0 FHIR R4 Client Test Suite'
      short_title 'Subscriptions R4 Client'
      version VERSION
      description File.read(File.join(__dir__, '..', 'docs',
                                      'subscriptions_r5_backport_r4_client_suite_description.md'))

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

      # All FHIR validation requests will use this FHIR validator
      fhir_resource_validator do
        igs 'hl7.fhir.uv.subscriptions-backport#1.1.0'

        exclude_message do |message|
          message.message.match?(/\A\S+: \S+: URL value '.*' does not resolve/)
        end
      end

      capability_statement = File.read(File.join(__dir__, 'subscriptions_r5_backport_r4_client', 'fixtures',
                                                 'capability_statement.json'))
      route(:get, '/fhir/metadata', proc { [200, { 'Content-Type' => 'application/json' }, [capability_statement]] })

      suite_endpoint :post, FHIR_SUBSCRIPTION_PATH, SubscriptionCreateEndpoint
      suite_endpoint :get, FHIR_SUBSCRIPTION_INSTANCE_PATH, SubscriptionReadEndpoint
      suite_endpoint :post, FHIR_SUBSCRIPTION_INSTANCE_STATUS_PATH, SubscriptionStatusEndpoint
      suite_endpoint :get, FHIR_SUBSCRIPTION_INSTANCE_STATUS_PATH, SubscriptionStatusEndpoint
      suite_endpoint :post, FHIR_SUBSCRIPTION_RESOURCE_STATUS_PATH, SubscriptionStatusEndpoint

      resume_test_route :get, RESUME_PASS_PATH do |request|
        request.query_parameters['test_run_identifier']
      end

      resume_test_route :get, RESUME_FAIL_PATH, result: 'fail' do |request|
        request.query_parameters['test_run_identifier']
      end

      group from: :subscriptions_r4_client_workflow
    end
  end
end
