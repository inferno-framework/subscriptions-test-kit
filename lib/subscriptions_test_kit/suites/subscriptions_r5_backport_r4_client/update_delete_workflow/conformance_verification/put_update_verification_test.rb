# frozen_string_literal: true

require_relative '../../../../common/subscription_conformance_verification'
require_relative 'update_request_loading'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class PutUpdateVerificationTest < Inferno::Test
      include SubscriptionConformanceVerification
      include UpdateRequestLoading

      id :subscriptions_r4_client_put_update_verification
      title 'Client Subscription PUT Update Conformance Verification'
      description %(
        This test verifies that any [update](https://hl7.org/fhir/R4/http.html#update) (`PUT`) requests
        that the client under test sent to Inferno for the Subscription it created during this session
        are conformant. Specifically, that
        - the `id` of the Subscription in the request body matches the `id` in the request URL, and
        - the Subscription in the request body is conformant to the [R4/B Topic-Based Subscription
          profile](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription.html)
          and meets other requirements placed on it by the IG.

        Clients may update the Subscription using either `PUT` or `PATCH`, so this test is omitted if the
        client only used `PATCH`.
      )

      run do
        subscription = load_update_requests('put')

        requests.each do |update_request|
          body_id = JSON.parse(update_request.request_body)['id'] if valid_json?(update_request.request_body)
          unless body_id == subscription.id
            add_message('error', %(
              The Subscription `id` in the update request body (`#{body_id}`) does not match the `id` in the
              request URL (`#{subscription.id}`).
            ))
          end
          subscription_verification(update_request.request_body)
        end

        no_error_verification('Subscription PUT update request is not conformant.')
      end

      def valid_json?(json)
        JSON.parse(json)
        true
      rescue JSON::ParserError, TypeError
        false
      end
    end
  end
end
