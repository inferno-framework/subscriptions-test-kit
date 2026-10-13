# frozen_string_literal: true

module SubscriptionsTestKit
  # Values shared by the FHIR validators that the client and server suites define
  # Validator definitions kept in the suites rather than pulled out into this module
  # to keep them local to the suites even though identical.
  SUBSCRIPTIONS_BACKPORT_IG = 'hl7.fhir.uv.subscriptions-backport#1.1.0'
  UNRESOLVED_URL_VALIDATION_MESSAGE = /\A\S+: \S+: URL value '.*' does not resolve/
end
