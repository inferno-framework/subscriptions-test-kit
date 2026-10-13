# frozen_string_literal: true

require_relative '../common/subscription_simulation_utils'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class UpdateDeleteInteractionTest < Inferno::Test
      include URLs
      include SubscriptionSimulationUtils

      id :subscriptions_r4_client_update_delete_interaction
      title 'Subscription Update and Delete Interaction'
      description %(
        During this test, Inferno will wait while the client system changes the Subscription
        that it created during the *Demonstrate the Rest-Hook Subscription Workflow* tests.
        Inferno accepts the FHIR [update](https://hl7.org/fhir/R4/http.html#update),
        [patch](https://hl7.org/fhir/R4/http.html#patch) (JSON only), and [delete](https://hl7.org/fhir/R4/http.html#delete)
        interactions and testers can demonstrate system support for any or all of them.

        Additional notes:
        - Inferno will not send additional notifications or handshakes based on the updated Subscription.
        - Inferno will modify the `Subscription.channel.payload` value on the updated Subscription to
          `application/fhir+json` unless it is `application/json`.
        - Inferno manages the `Subscription.status` value and will ignore requested changes to it, unless
          the requested status is `off`.
        - Inferno only accepts updates and deletes of the Subscription while this test is waiting.
        - Each run of this test starts from the Subscription as created during the *Demonstrate the Rest-Hook
          Subscription Workflow* tests. Changes made during earlier runs of this test, including deletion,
          are not carried over.
      )

      input :access_token,
            title: 'Access Token',
            description: %(
              The bearer token that the client under test will use when making Subscription update, delete, and other
              requests to Inferno's simulated Subscriptions server.
            )
      # Inferno's Subscription update and delete endpoints only accept requests while this test is waiting
      config options: { accepts_subscription_changes: true }

      output :confirmation_url
      output :fail_url
      output :subscription_url

      run do
        subscription = find_subscription(test_session_id)
        skip_if(subscription.nil?, %(
          No Subscription was created in this session. Run the *Demonstrate the Rest-Hook Subscription Workflow*
          tests before running these tests.
        ))

        subscription_url = "#{fhir_subscription_url}/#{subscription.id}"
        output(subscription_url:)
        confirmation_url = "#{resume_pass_url_client}?test_run_identifier=#{access_token}"
        output(confirmation_url:)
        fail_url = "#{resume_fail_url_client}?test_run_identifier=#{access_token}"
        output(fail_url:)

        wait(
          identifier: access_token,
          timeout: 600,
          message: <<~MESSAGE
            Inferno will wait while the client updates and/or deletes the Subscription created earlier
            in the session. The Subscription is in the state it was created in: changes made during
            earlier runs of these tests, including deletion, have not been kept. Inferno accepts the FHIR [update](https://hl7.org/fhir/R4/http.html#update),
            [patch](https://hl7.org/fhir/R4/http.html#patch) (JSON only), and [delete](https://hl7.org/fhir/R4/http.html#delete)
            interactions and testers can demonstrate system support for any or all of them by making
            a request using the corresponding HTTP verb against `#{subscription_url}`:

            - **PUT**: Change the Subscription with the update interaction by sending
              a PUT request containing an updated Subscription resource in the request body.
            - **PATCH**: Change the Subscription with a patch interaction by sending
              a PATCH request containing a JSON Patch (`Content-Type: application/json-patch+json`)
              in the request body
            - **DELETE**: Remove the Subscription with a delete interaction by sending a
              DELETE request with no body.

            All requests must have the Authorization header set to:

            `Bearer #{access_token}`

            At any point while this test is waiting, Inferno will respond to Subscription GET and $status requests
            for the Subscription until it has been deleted.

            Once the client has demonstrated the Subscription interactions it supports,
            [click here to complete the test](#{confirmation_url})

            If at any point something has gone wrong and the client is unable to continue,
            [click here to fail the test](#{fail_url})
          MESSAGE
        )
      end
    end
  end
end
