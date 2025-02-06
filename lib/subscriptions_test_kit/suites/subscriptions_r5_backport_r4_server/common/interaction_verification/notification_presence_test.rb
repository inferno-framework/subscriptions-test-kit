module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class NotificationPresenceTest < Inferno::Test
      id :subscriptions_r4_server_notification_presence
      title 'Notification Presence Verification'
      description %(
        This test identifies the most recent successfully created Subscription (from the just-run interaction test)
        and checks that the server sent at least one notification to Inferno's notification endpoint
        regarding that Subscription. This test does not check the types of these notifications or
        whether they are conformant.
      )

      def subscription_type
        config.options[:subscription_type]
      end

      run do
        if subscription_type.present?
          requests = load_tagged_requests('subscription_creation', subscription_type)
          subscription_requests =
            requests
              .select { |request| request.status == 201 }
          skip_if subscription_requests.empty?, %(
                    No successful Subscription creation request of type #{subscription_type}
                    was made in the previous test.
                  )
        else
          all_requests = load_tagged_requests('subscription_creation')
          subscription_requests =
            all_requests
              .select { |request| request.status == 201 }
          skip_if subscription_requests.empty?,
                  'No successful Subscription creation request was made in the previous test.'
        end

        # select the most recent subscription to verify
        # this test is run as part of the interaction group, so the most recent
        # successfully created Subscription will be the one that came during
        # the previoius interaction test
        latest_subscription = nil
        subscription_requests.each do |subscription_request|
          if latest_subscription.blank? || latest_subscription.created_at < subscription_request.created_at
            latest_subscription = subscription_request
          end
        end

        assert_valid_json(latest_subscription.response_body)
        subscription = JSON.parse(latest_subscription.response_body)

        requests = load_tagged_requests(subscription['id'])
        assert !requests.empty?,
               "No notifications were received from the server related to Subscription #{subscription['id']}."
      end
    end
  end
end
