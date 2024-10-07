require_relative '../subscription_creation'
require_relative '../../../../urls'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class NotificationDeliveryTest < Inferno::Test
      include SubscriptionCreation
      include URLs

      id :subscriptions_r5_backport_r4_server_notification_delivery
      title 'Send Subscription and Receive Notification Requests from Server'
      description %(
        This test sends a request to create the Subscription resource to the Subscriptions Backport FHIR Server.
        If successful, it then waits for [notification](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/notifications.html#notifications)
        requests of the following types:
          - handshake (required for `rest-hook` notifications)
          - heartbeat (required if `heartbeatPeriod` field is populated in Subscription resource)
          - event-notification
      )
      config options: { accepts_multiple_requests: true }

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@133'

      input :updated_subscription
      input :access_token,
            title: 'Notification Access Token',
            description: %(
              An access token that the server under test will send to Inferno on notifications
              so that the request gets associated with this test session. The token must be
              provided as a `Bearer` token in the `Authorization` header of HTTP requests
              sent to Inferno.
            )

      run do
        subscription = JSON.parse(updated_subscription)
        subscription_type = send_subscription(subscription)

        wait(
          identifier: "notification #{access_token}",
          message: %(
            **Subscription `#{subscription['id']}`: `#{subscription_type}` Notification Test**

            Send any handshake, heartbeat, and `#{subscription_type}` event-notification requests for the Subscription
            with id `#{subscription['id']}` to:

            `#{subscription_channel_url}`

            [Click here](#{resume_pass_url}?token=notification%20#{access_token}) when you have finished submitting
            requests.

          )
        )
      end
    end
  end
end
