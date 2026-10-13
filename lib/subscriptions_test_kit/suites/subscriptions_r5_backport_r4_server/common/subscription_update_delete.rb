module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    module SubscriptionUpdateDelete
      def created_subscription_id
        creation_requests = load_tagged_requests('subscription_creation', 'workflow').select { |r| r.status == 201 }
        skip_if creation_requests.empty?, %(
          No successful Subscription creation request has been made during the "Demonstrate the Subscription Workflow"
          group. Run that group successfully before re-running this one.
        )

        JSON.parse(creation_requests.first.response_body)['id']
      end

      # Returns the raw JSON hash so that primitive extensions, such as the payload content extension on
      # Subscription.channel.payload, are preserved
      def read_subscription_json(subscription_id)
        fhir_read(:subscription, subscription_id)
        assert_response_status(200)
        assert_valid_json(request.response_body)
        JSON.parse(request.response_body)
      end

      # FHIR models drop primitive extensions, so send the raw JSON as the body of the update
      def raw_subscription_resource(subscription_hash)
        FHIR::Subscription.new(subscription_hash).tap do |resource|
          resource.define_singleton_method(:to_json) { |*| subscription_hash.to_json }
        end
      end

      def updated_reason(subscription, interaction)
        "#{subscription['reason']} (updated by Inferno using #{interaction} at #{Time.now.utc.iso8601})"
      end

      def verify_reason_updated(subscription_id, expected_reason)
        subscription = read_subscription_json(subscription_id)
        assert(subscription['reason'] == expected_reason, %(
          Expected the `reason` of the updated Subscription to be `#{expected_reason}`, but was
          `#{subscription['reason']}`.
        ))
      end
    end
  end
end
