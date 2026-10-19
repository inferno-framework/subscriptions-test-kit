# frozen_string_literal: true

require_relative 'subscriptions_r5_backport_r4_client/workflow_group'
require_relative 'subscriptions_r5_backport_r4_client/update_delete_workflow_group'
require_relative '../fhir_validation'
require_relative '../endpoints/subscription_create_endpoint'
require_relative '../endpoints/subscription_read_endpoint'
require_relative '../endpoints/subscription_update_endpoint'
require_relative '../endpoints/subscription_patch_endpoint'
require_relative '../endpoints/subscription_delete_endpoint'
require_relative '../endpoints/subscription_status_endpoint'
require_relative '../endpoints/subscription_type_status_endpoint'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class SubscriptionsR5BackportR4ClientSuite < Inferno::TestSuite
      id :subscriptions_r5_backport_r4_client
      title 'Subscriptions R5 Backport IG v1.1.0 FHIR R4 Client Test Suite'
      short_title 'Subscriptions R4 Client'
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

      requirement_sets(
        {
          identifier: 'hl7.fhir.uv.subscriptions_1.1.0',
          title: 'Subscriptions R5 Backport IG',
          actor: 'Client'
        }
      )

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

      capability_statement = File.read(File.join(__dir__, 'subscriptions_r5_backport_r4_client', 'fixtures',
                                                 'capability_statement.json'))
      if Inferno::Application['base_url'].start_with? 'https://inferno-qa.healthit.gov'
        capability_statement.gsub!('https://inferno.healthit.gov', 'https://inferno-qa.healthit.gov')
      end
      route(:get, '/fhir/metadata', proc {
                                      [200, { 'Content-Type' => 'application/fhir+json' }, [capability_statement]]
                                    })

      suite_endpoint :post, FHIR_SUBSCRIPTION_PATH, SubscriptionCreateEndpoint
      suite_endpoint :get, FHIR_SUBSCRIPTION_INSTANCE_PATH, SubscriptionReadEndpoint
      suite_endpoint :put, FHIR_SUBSCRIPTION_INSTANCE_PATH, SubscriptionUpdateEndpoint
      suite_endpoint :patch, FHIR_SUBSCRIPTION_INSTANCE_PATH, SubscriptionPatchEndpoint
      suite_endpoint :delete, FHIR_SUBSCRIPTION_INSTANCE_PATH, SubscriptionDeleteEndpoint
      suite_endpoint :post, FHIR_SUBSCRIPTION_INSTANCE_STATUS_PATH, SubscriptionStatusEndpoint
      suite_endpoint :get, FHIR_SUBSCRIPTION_INSTANCE_STATUS_PATH, SubscriptionStatusEndpoint
      suite_endpoint :post, FHIR_SUBSCRIPTION_RESOURCE_STATUS_PATH, SubscriptionTypeStatusEndpoint
      suite_endpoint :get, FHIR_SUBSCRIPTION_RESOURCE_STATUS_PATH, SubscriptionTypeStatusEndpoint

      resume_test_route :get, RESUME_PASS_PATH do |request|
        request.query_parameters['test_run_identifier']
      end

      resume_test_route :get, RESUME_FAIL_PATH, result: 'fail' do |request|
        request.query_parameters['test_run_identifier']
      end

      group from: :subscriptions_r4_client_workflow
      group from: :subscriptions_r4_client_update_delete_workflow
    end
  end
end
