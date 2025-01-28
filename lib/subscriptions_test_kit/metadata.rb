require_relative 'version'

module SubscriptionsTestKit
  class Metadata < Inferno::TestKit
    id :subscriptions_test_kit
    title 'Subscription Test Kit'
    description <<~DESCRIPTION
      The Subscriptions Test Kit verifies the conformance of systems to
      [FHIR Subscriptions framework](https://www.hl7.org/fhir/R5/subscriptions.html)
      specified in the R5 version and above. For R4 and R4B it checks conformance against
      the STU 1.1 version of the [Subscriptions R5 Backport
      IG](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/index.html).
      The test kit includes suites targeting the following actors from the specification:

      - **Subscription Servers**: Inferno will simulate a client by requesting a Subscription
        and accepting and evaluating the resulting notifications from the server under test.
      - **Subscription Clients**: Inferno will simulate a server by waiting for a Subscription
        request and then sending notifications based on it back to the client under test.

      In each case, content provided by the system under test will be checked individually
      for conformance and in aggregate to determine that it supports the full set of required
      features.
      <!-- break -->
    DESCRIPTION
    suite_ids [:subscriptions_r5_backport_r4_server, :subscriptions_r5_backport_r4_client]
    tags ['Subscriptions']
    last_updated '2025-01-28'
    version VERSION
    maturity 'Low'
    authors ['Karl Naden, Emily Semple, Tom Strassner']
    repo 'https://github.com/inferno-framework/subscriptions-test-kit'
  end
end
