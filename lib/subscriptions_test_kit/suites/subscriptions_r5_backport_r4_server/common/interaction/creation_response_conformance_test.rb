module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Server
    class CreationResponseConformanceTest < Inferno::Test
      id :subscriptions_r4_server_creation_response_conformance
      title 'Verify Subscription Creation Response'
      description %(
        This test ensures that the server responded to the Subscription creation test with the new created Subscription
        resource. If the Subscription's channel type is set to 'rest-hook', the test will ensure that the Subscription's
        status is set to 'requested'.
      )

      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@7',
                            'hl7.fhir.uv.subscriptions_1.1.0@25',
                            'hl7.fhir.uv.subscriptions_1.1.0@49',
                            'hl7.fhir.uv.subscriptions_1.1.0@29'

      def subscription_type
        config.options[:subscription_type]
      end

      run do
        if subscription_type.present?
          subscription_requests = load_tagged_requests('subscription_creation', subscription_type)
          requests =
            subscription_requests
              .select { |request| request.status == 201 }
          skip_if requests.empty?, 'No successful Subscription creation request was made in the previous test.'
        else
          all_requests = load_tagged_requests('subscription_creation')
          all_subscription_requests =
            all_requests
              .select { |request| request.status == 201 }
          skip_if all_subscription_requests.empty?,
                  'No successful Subscription creation request was made in the previous test.'
          requests = [all_subscription_requests.first]
        end

        requests.each do |subscription_request|
          assert_valid_json(subscription_request.response_body)
          subscription = FHIR.from_contents(subscription_request.response_body)
          assert subscription.present?, 'Not a FHIR resource'

          assert_resource_type('Subscription', resource: subscription)

          assert(subscription.channel.type == 'rest-hook' && subscription.status == 'requested',
                 "The Subscription resource should have it's status set to 'requested', was '#{subscription.status}'")
        end
      end
    end
  end
end
