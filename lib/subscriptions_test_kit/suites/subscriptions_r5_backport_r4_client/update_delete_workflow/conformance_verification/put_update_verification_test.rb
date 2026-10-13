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
        This test verifies that the [update](https://hl7.org/fhir/R4/http.html#update) (`PUT`) requests
        that the client under test sent to Inferno for the Subscription it created during this session
        are conformant. Specifically, that each request
        - was accepted by Inferno, which requires, for example, that the `id` of the Subscription in the request
          body matches the `id` in the request URL, and
        - contained a Subscription in the request body that is conformant to the [R4/B Topic-Based Subscription
          profile](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription.html)
          and meets other requirements placed on it by the IG.

        Requests sent for other Subscription ids are not considered. Clients may update the Subscription using
        either `PUT` or `PATCH`, so this test is omitted if the client only used `PATCH`.
      )

      run do
        load_update_requests('put')

        verify_update_requests do |update_request|
          subscription_verification(update_request.request_body)
        end
      end
    end
  end
end
