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
        This test verifies that the [patch](https://hl7.org/fhir/R4/http.html#patch) (`PATCH`) requests
        that the client under test sent to Inferno for the Subscription it created during this session
        are conformant. Specifically, that each request
        - was a [JSON Patch](https://datatracker.ietf.org/doc/html/rfc6902) that Inferno was able to
          apply to the Subscription, and
        - resulted in a patched Subscription that is conformant to the [R4/B Topic-Based Subscription
          profile](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription.html)
          and meets other requirements placed on it by the IG.

        Requests sent for other Subscription ids are not considered.

        Inferno manages the `Subscription.status` and `Subscription.channel.payload` values itself (see the
        *Subscription Update and Delete Interaction* test), so the values that the patch gives those elements
        are not verified and not used by Inferno.

        Inferno does not support XML Patch or FHIRPath Patch requests.
      )

      run do
        load_update_requests('patch')

        verify_update_requests do |patch_request|
          # The response contains the Subscription with the patch applied, except for the status and
          # payload values that Inferno manages
          subscription_verification(patch_request.response_body)
        end
      end
    end
  end
end
