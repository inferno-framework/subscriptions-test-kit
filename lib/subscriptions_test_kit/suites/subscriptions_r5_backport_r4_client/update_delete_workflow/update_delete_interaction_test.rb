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
        During this test, the client under test will update and then delete the Subscription
        that it created during the *Demonstrate the Rest-Hook Subscription Workflow* tests.
        This includes the following steps
        1. The client under test sends a Subscription update (`PUT`) or patch (`PATCH`) request to Inferno
           for the previously created Subscription.
        2. The client under test sends a Subscription delete (`DELETE`) request to Inferno
           for the previously created Subscription.

        While these steps are taking place and after, Inferno will be waiting for the user to indicate that
        the interaction has completed successfully or failed for some reason. Additionally, the client
        system may make additional requests, such as Subscription reads or `$status` checks, while the
        test is waiting. Afterwards, Inferno will no longer respond to requests.

        Additional notes:
        - Inferno will not send additional notifications based on the updated Subscription.
        - Inferno only supports `PATCH` requests that use
          [JSON Patch](https://datatracker.ietf.org/doc/html/rfc6902) with a `Content-Type` of
          `application/json-patch+json`.
        - Inferno will modify the `Subscription.channel.payload` value on the updated Subscription to
          `application/fhir+json` unless it is `application/json`.
        - Inferno manages the `Subscription.status` value and will ignore requested changes to it, unless
          the requested status is `off`.
      )

      input :access_token,
            title: 'Access Token',
            description: %(
              The bearer token that the client under test will use when making Subscription update, delete, and other
              requests to Inferno's simulated Subscriptions server.
            )
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
          message: %(
            Inferno will wait until the client has updated and deleted the Subscription. The steps are:

            1. Inferno expects either a Subscription PUT request containing the updated Subscription or a
            Subscription PATCH request containing a JSON Patch (`Content-Type: application/json-patch+json`) at:

              `#{subscription_url}`

            2. Inferno then expects a Subscription DELETE request at:

              `#{subscription_url}`

            All requests must have the Authorization header set to:

            `Bearer #{access_token}`

            At any point while this test is waiting, Inferno will respond to Subscription GET and $status requests
            for the Subscription until it has been deleted.

            Once the client has updated and deleted the Subscription and has made any additional requests,
            [click here to complete the test](#{confirmation_url})

            If at any point something has gone wrong and the client is unable to continue,
            [click here to fail the test](#{fail_url})

            NOTE: The test must be completed or failed using the links above within 10 minutes. After that,
            attempts to send requests or to complete or fail the tests using the links above
            will result in a *"session not found"* error.
          )
        )
      end
    end
  end
end
