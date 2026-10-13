# frozen_string_literal: true

require_relative 'conformance_verification/put_update_verification_test'
require_relative 'conformance_verification/patch_update_verification_test'
require_relative 'conformance_verification/delete_verification_test'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    class UpdateDeleteConformanceVerificationGroup < Inferno::TestGroup
      id :subscriptions_r4_client_update_delete_conformance_verification
      title 'Subscription Update and Delete Conformance Verification'

      test from: :subscriptions_r4_client_put_update_verification, optional: true
      test from: :subscriptions_r4_client_patch_update_verification, optional: true
      test from: :subscriptions_r4_client_delete_verification, optional: true
    end
  end
end
