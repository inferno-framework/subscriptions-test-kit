# frozen_string_literal: true

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class InteractionTest < Inferno::Test
      id :subscriptions_r4_client_interaction
      description %(
        During this test, the client under test will interact with Inferno following the Subscription
        workflow over a `rest-hook` channel. This includes the following steps
        1. The client under test sends a Subscription request to Inferno
        2. Inferno sends a handshake notification request to the endpoint specified in the Subscription.
        3. Inferno sends an event notification request to the endpoint specified in the Subscription.

        While these steps are taking place and after, Inferno will be waiting for the user to indicate that
        the interaction has completed successfully or failed for some reason. Additionally, the client
        system may make additional requests, such as `$status` checks, while the test is waiting.
        Afterwards, Inferno will no longer respond to requests.

        To create the handshake and event notifications, Inferno uses the contents of the *Event
        Notification Bundle* input. The provided notification will be modified as appropriate for 
        the request Inferno is making:
        - General changes for all notification types
          - update the `subscription` parameter entry reference.
          - update the `status` parameter entry based on the previous interactions.
          - update the `type` parameter entry based on the notification type (e.g., `event-notification` or `handshake`).
          - update the number of notifications sent in the `events-since-subscription-start` parameter entry.
        - `handshake`-specific changes:
          - clear the `events` parameter entry.
          - clear the `errors` parameter entry.

        While the provided Notification must be conformant to the 
        [R4 Topic-Based Subscription Notification Bundle 
        profile](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription-notification-r4.html)
        for the tests to pass, the tests can run as long as the notification meets the
        following minimal requirements:
        1. The provided content must be a valid json representation of a FHIR Bundle resource.
        2. The first instance in the Bundle is a Parameters resource.
        3. The first Parameters instance has a `subscription` parameter entry.
      )
      title 'Subscription Workflow Interaction'

      input :access_token,
            title: 'Access Token',
            description: %(
              The bearer token that the client under test will use when making Subscription creation, $status, and other
              requests to Inferno's simulated Subscriptions server.
            )
      input :client_endpoint_access_token,
            optional: true,
            title: 'Client Notification Access Token',
            description: %(
              The bearer token that Inferno will send on requests to the client under test's rest-hook notification endpoint. Not
              needed if the client under test will create a Subscription with an appropriate header value in the
              `channel.header` element. If a value for the `authorization` header is provided in `channel.header`, this
              value will override it.
            )
      input :notification_bundle,
            title: 'Event Notification Bundle',
            type: 'textarea',
            description: %(
              The event notification bundle from which Inferno will derive a handshake notification, an event
              notification to send to the client endpoint, and responses to $status operation requests. The provided
              Bundle must conform to the R4 Topic-Based Subscription Notification Bundle profile.
            )

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@23'

      run do
        minimally_validate_notification(notification_bundle)
        assert(messages.none? { |m| m[:type] == 'error' }, 'Notification Bundle input is invalid for use by Inferno, see error message(s)')

        wait(
          identifier: access_token,
          timeout: 600,
          message: %(
            Inferno will wait until the the event notification workflow is complete. The steps in the workflow are:

            1. Inferno expects a Subscription POST request at:

              `#{fhir_subscription_url}`

              with the Authorization header set to:

              `Bearer #{access_token}`

            2. Inferno will send a handshake notification to the rest-hook endpoint specified in the subscription.

            3. After a 5–10 second delay, Inferno will send an event notification to the rest-hook endpoint.

            At any point while this test is waiting, Inferno will respond to Subscription GET and $status requests.

            Once the client has received an event notification and has made any additional requests,
            [click here to complete the test](#{resume_pass_url}?test_run_identifier=#{access_token})

            If at any point something has gone wrong and the client is unable to continue,
            [click here to fail the test](#{resume_fail_url}?test_run_identifier=#{access_token})

            NOTE: The test must be completed or failed using the links above within 10 minutes. After that,
            attempts to send requests or to complete or fail the tests using the links above
            will result in a *"session not found"* error.
          )
        )
      end

      # Perform only the verification necessary for the Inferno test to function
      def minimally_validate_notification(notification_bundle)
        assert_valid_json(notification_bundle)
        begin
          bundle = FHIR.from_contents(notification_bundle)
        rescue StandardError
          assert(false, 'Notification bundle input is not a conformant FHIR Bundle')
        end
        assert_resource_type(:bundle, resource: bundle)
        subscription_status = bundle.entry&.first&.resource
        assert(subscription_status.present?, 'Notification bundle input must contain a subscription status entry')
        assert_resource_type(:parameters, resource: subscription_status)

        # Require the subscription param, just because we need something to later identify the subscription status
        # bundle entry. Note we could just as easily use a different required param, like status or type.
        subscription_param = subscription_status.parameter&.find { |p| p.name == 'subscription' }
        assert(subscription_param.present?, 'Subscription status entry in notification bundle input must contain a'\
                                            'subscription parameter')
      rescue Inferno::Exceptions::AssertionException => e
        add_message('error', e.message)
      end
    end
  end
end