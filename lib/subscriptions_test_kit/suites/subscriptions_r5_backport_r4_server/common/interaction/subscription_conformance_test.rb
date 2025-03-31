require_relative '../../../../common/subscription_conformance_verification'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class SubscriptionConformanceTest < Inferno::Test
      include SubscriptionConformanceVerification

      id :subscriptions_r4_server_subscription_conformance
      title '[USER INPUT VERIFICATION] Verify Subscription to Send to Server'
      description %(
        This test accepts a Subscription resource as an input and verifies that it is conformant to the
        [R4/B Topic-Based Subscription profile](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription.html)
        and that it is constructed to make supported notifications to Inferno's simulated
        Subscriptions client.

        For the server to successfuly deliver notifications recognized by this test session, the Subscription `channel`
        element should have it's subelements populated with the following information:
        - The `endpoint` field must be set to
          `#{Inferno::Application['base_url']}/custom/subscriptions_r5_backport_r4_server#{SUBSCRIPTION_CHANNEL_PATH}`.
          The test will add the correct url to this field if it is not properly set.
        - The `type` element must be set to `rest-hook`, as the Inferno subscription workflow tests use a `rest-hook`
          subscription channel to receive incoming notifications. The test will add the correct type to this field if it
          is not properly set.
        - The `payload` element should be `application/fhir+json`. Inferno will update it to that value
          unless the provided value is `application/json`, which Inferno also supports receiving as the
          `content-type` HTTP header on notifications.
        - The `header` element must include the `Authorization` header with a Bearer token set to the inputted Inferno
          access token to direct the server to send that header to identify the notifications are for this session.
          Inferno will add the entry if it is not present.
      )

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@72',
                            'hl7.fhir.uv.subscriptions_1.1.0@73',
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

      output :updated_subscription

      run do
        omit_if subscription_resource.blank?, 'Did not input a Subscription resource of this type.'
        assert_valid_json(subscription_resource)
        assert_resource_type('Subscription', resource: FHIR.from_contents(subscription_resource))

        subscription = JSON.parse(subscription_resource)

        begin
          subscription_verification(subscription_resource)
          no_error_verification('Subscription resource is not conformant.')
          subscription = server_check_channel(subscription, access_token)
        ensure
          output updated_subscription: subscription.to_json
        end
      end
    end
  end
end
