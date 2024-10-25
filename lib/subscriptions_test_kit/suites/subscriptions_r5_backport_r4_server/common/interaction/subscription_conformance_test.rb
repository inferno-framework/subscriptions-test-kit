require_relative '../../../../common/subscription_conformance_verification'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class SubscriptionConformanceTest < Inferno::Test
      include SubscriptionConformanceVerification

      id :subscriptions_r4_server_subscription_conformance
      title '[USER INPUT VERIFICATION] Verify Subscription to Send to Server'
      description %(
        The Subscription resource is used to request notifications for a specific client about a specific topic
        Conceptually, a subscription is a concrete request for a single client to receive notifications per a single
        topic. In order to support topic-based subscriptions in R4, this guide defines several extensions for use on the
        [R4 Subscription resource](http://hl7.org/fhir/R4/subscription.html). A list of extensions defined by this guide
        can be found on the
        [Subscriptions R5 Backport IG's Artifacts page](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/artifacts.html#5).

        This test accepts a Subscription resource as an input and verifies that it is conformant to the
        [R4/B Topic-Based Subscription profile](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription.html).

        The Subscription channel should have it's fields populated with the following information:
          - The `endpoint` field must be set to
          `#{Inferno::Application['base_url']}/custom/subscriptions_r5_backport_r4_server#{SUBSCRIPTION_CHANNEL_PATH}`.
          The test will add the correct url to this field if it is not properly set.
          - The `type` field must be set to `rest-hook`, as the Inferno subscription workflow tests use a `rest-hook`
          subscription channel to receive incoming notifications. The test will add the correct type to this field if it
          is not properly set.
          - The `payload` field must be set to `application/json`, as Inferno will only accept resources in requests
          with this content type.
          - The `header` field must include the `Authorization` header with a Bearer token set to the inputted Inferno
          access token.
      )

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@72',
                            'hl7.fhir.uv.subscriptions_1.1.0@86'

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
      input :access_token,
            title: 'Notification Access Token',
            description: %(
              An access token that the server under test will send to Inferno on notifications
              so that the request gets associated with this test session. The token must be
              provided as a `Bearer` token in the `Authorization` header of HTTP requests
              sent to Inferno.
            )

      output :updated_subscription, :subscription_topic
      
      def valid_url?(url)
        uri = URI.parse(url)
        uri.is_a?(URI::HTTP) && !uri.host.nil?
        rescue URI::InvalidURIError
        false
      end

      run do
        omit_if subscription_resource.blank?, 'Did not input a Subscription resource of this type.'
        subscription = subscription_verification(subscription_resource)
        no_error_verification('Subscription resource is not conformant.')

        assert(subscription['criteria'].present? && subscription['criteria'].valid_url?,
               'The `criteria` field SHALL be populated and contain the canonical URL for the Subscription Topic.')
        output subscription_topic: subscription['criteria']
        
        subscription = server_check_channel(subscription, access_token)
        output updated_subscription: subscription.to_json
      end
    end
  end
end
