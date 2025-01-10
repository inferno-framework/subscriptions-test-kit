# frozen_string_literal: true

require_relative '../../../../common/subscription_conformance_verification'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class SubscriptionVerificationTest < Inferno::Test
      include SubscriptionConformanceVerification
      id :subscriptions_r4_client_subscription_verification
      title 'Client Subscription Conformance Verification'
      description %(
        This test verifies that the Subscription created by the client under test
        is conformant to the [R4/B Topic-Based Subscription
        profile](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription.html)
        and meets other requirements placed on it by the IG.
      )
      verifies_requirements 'hl7.fhir.uv.subscriptions_1.1.0@68',
                            'hl7.fhir.uv.subscriptions_1.1.0@76',
                            'hl7.fhir.uv.subscriptions_1.1.0@86'

      run do
        load_tagged_requests(SUBSCRIPTION_CREATE_TAG)
        skip_if(requests.none?, 'Inferno did not receive a Subscription creation request')
        subscription_verification(request.request_body)
        no_error_verification('Subscription resource is not conformant.')
      end
    end
  end
end
