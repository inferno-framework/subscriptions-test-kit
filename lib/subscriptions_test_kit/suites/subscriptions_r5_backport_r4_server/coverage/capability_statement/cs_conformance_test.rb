module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class CSConformanceTest < Inferno::Test
      id :subscriptions_r5_backport_r4_server_cs_conformance
      title 'Capability Statement Conformance Verification'
      description %(
        This test attempts to retreive the server's Capability Statement in order to verify that it
        declares support for the Backport Subscription Profile by including its official URL in the server's
        CapabilityStatement.rest.resource.supportedProfile element: http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/backport-subscription
      )

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@52',
                            'hl7.fhir.uv.subscriptions_1.1.0@114',
                            'hl7.fhir.uv.subscriptions_1.1.0@120'

      def subscription_profile_url
        'http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/backport-subscription'
      end

      run do
        fhir_get_capability_statement
        assert_response_status(200)
        assert_resource_type(:capability_statement)
        assert_valid_resource

        scratch[:capability_statement] ||= resource

        assert(resource.rest.present?, 'Capability Statement missing the `rest` field')
        rest_server = resource.rest.find { |elem| elem.mode == 'server' }
        assert(rest_server.present?, "Capability Statement missing entry in `rest` with a `mode` set to 'server'")

        rest_subscription = rest_server.resource.find { |elem| elem.type == 'Subscription' }
        assert(rest_subscription.present?, 'Capability Statement missing `Subscription` resource in `rest` field')

        assert(rest_subscription.supportedProfile.present?,
              'Capability Statement missing the `supportedProfile` field in `Subscription` resource')

        subscription_profile_present = rest_subscription.supportedProfile.any? do |profile|
          profile == subscription_profile_url
        end
        unless subscription_profile_present
          add_message('warning', %(
            Subscription resource should declare support for the Backport Subscription Profile by including its
            official URL))
        end
      end
    end
  end
end
