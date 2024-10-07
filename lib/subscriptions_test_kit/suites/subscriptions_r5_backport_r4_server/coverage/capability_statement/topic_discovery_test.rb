require_relative '../../../../common/subscription_conformance_verification'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class TopicDiscoveryTest < Inferno::Test
      include SubscriptionConformanceVerification

      id :subscriptions_r5_backport_r4_server_topic_discovery
      title 'Attempt topic discovery'
      description %(
        This test attempts to perform topic discovery with the server. In order to allow for [discovery of supported
        subscription topics in R4](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/components.html#subscription-topics-in-r4),
        the Subscriptions Backport IG defines the CapabilityStatement [SubscriptionTopic Canonical extension](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-capabilitystatement-subscriptiontopic-canonical.html).
        The extension allows server implementers to advertise the canonical URLs of topics available to clients and
        allows clients to see the list of supported topics on a server.

        The extension is expected to appear, if supported, on the Subscription resource entry. Note that servers are NOT
        required to advertise supported topics via this extension, so this test it optional. Supported topics can also
        be advertised, for example, by the CapabilityStatement.instantiates or CapabilityStatement.implementationGuide
        elements of a CapabilityStatement, as defined by another Implementation Guide. Finally, FHIR R4 servers MAY
        choose to leave topic discovery completely out-of-band and part of other steps, such as registration or
        integration.

        In order to claim conformance with this IG for R4, a server SHOULD support topic discovery
        via the CapabilityStatement SubscriptionTopic Canonical extension.
      )

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@2',
                            'hl7.fhir.uv.subscriptions_1.1.0@48'

      optional

      def backport_subscription_server_url
        'http://hl7.org/fhir/uv/subscriptions-backport/CapabilityStatement/backport-subscription-server-r4'
      end

      def subscription_profile_url
        'http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/backport-subscription'
      end

      def capability_statement_subscriptiontopic_extension
        'http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/capabilitystatement-subscriptiontopic-canonical'
      end

      def scratch_resource
        scratch[:capability_statement] ||= {}
      end

      run do
        resource = scratch_resource

        skip_if resource.blank?, 'No Capability Statement received in previous test'

        assert(resource.rest.present?, 'Capability Statement missing the `rest` field')
        rest_server = resource.rest.find { |elem| elem.mode == 'server' }
        assert(rest_server.present?, "Capability Statement missing entry in `rest` with a `mode` set to 'server'")

        rest_subscription = rest_server.resource.find { |elem| elem.type == 'Subscription' }
        assert(rest_subscription.present?, 'Capability Statement missing `Subscription` resource in `rest` field')

        assert(rest_subscription.extension.present?,
              'Capability Statement missing the `extension` field on the Subscription resource')
        subscription_topic_extension = rest_subscription.extension.select do |elem|
          elem.url == capability_statement_subscriptiontopic_extension
        end
        assert(subscription_topic_extension.any?, %(
              The server SHOULD support topic discovery via the CapabilityStatement SubscriptionTopic Canonical
              extension))

        subscription_requests = load_tagged_requests('subscription_creation')

        if subscription_requests.any?
          subscription_topics =
            subscription_requests
              .select { |request| request.status == 201 }
              .uniq(&:response_body)
              .map { |request| JSON.parse(request.response_body) }
              .map { |subscription| subscription['criteria'] }
              .uniq

          if subscription_topics.any?
            subscription_topics.each do |subscription_topic|
              next if subscription_topic_extension.any? { |elem| elem.valueCanonical == subscription_topic }

              add_message('error', %(
                  The SubscriptionTopic Canonical extension should include the Subscription Topic URLs found in
                  Subscription.criteria: #{subscription_topic}))
            end
          else
            add_message('warning', %(
              Subscriptions missing criteria field containing a Subscription topic URL. Could not verify any
              topics found in the SubscriptionTopic Canonical extension))
          end

          no_error_verification(
            "Subscription.criteria value(s) not found in Capability Statement's SubscriptionTopic Canonical extension"
          )
        else
          add_message('warning', %(
            No Subscription requests have been made in previous tests. Run the Subscription workflow tests first in order
            to verify topics found in the SubscriptionTopic Canonical extension))
        end
      end
    end
  end
end
