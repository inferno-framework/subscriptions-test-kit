# frozen_string_literal: true

require_relative '../../../../common/subscription_conformance_verification'
require_relative 'update_request_loading'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class PatchUpdateVerificationTest < Inferno::Test
      include SubscriptionConformanceVerification
      include UpdateRequestLoading

      id :subscriptions_r4_client_patch_update_verification
      title 'Client Subscription PATCH Update Conformance Verification'
      description %(
        This test verifies that any [patch](https://hl7.org/fhir/R4/http.html#patch) (`PATCH`) requests
        that the client under test sent for the Subscription it created in this session
        are conformant. Specifically, that
        - the request is a [JSON Patch](https://datatracker.ietf.org/doc/html/rfc6902) that Inferno was able to
          apply to the Subscription, and
        - the patched Subscription is conformant to the [R4/B Topic-Based Subscription
          profile](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription.html)
          and meets other requirements placed on it by the IG.

        Inferno does not support XML Patch or FHIRPath Patch requests. Clients may update the Subscription
        using either `PUT` or `PATCH`, so this test is omitted if the client only used `PUT`.
      )

      run do
        load_update_requests('patch')

        requests.each do |patch_request|
          if patch_request.status == 200
            # The response contains the Subscription with the patch applied
            subscription_verification(patch_request.response_body)
          else
            add_message('error', %(
              Inferno could not apply the PATCH request (status #{patch_request.status}):
              #{error_response_text(patch_request.response_body)}
            ))
          end
        end

        no_error_verification('Subscription PATCH update request is not conformant.')
      end

      def error_response_text(response_body)
        JSON.parse(response_body).dig('issue', 0, 'details', 'text') || 'no details provided'
      rescue JSON::ParserError, TypeError
        'no details provided'
      end
    end
  end
end
