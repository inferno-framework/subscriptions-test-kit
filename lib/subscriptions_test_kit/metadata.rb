require_relative 'version'

module SubscriptionsTestKit
  class Metadata < Inferno::TestKit
    id :subscriptions_test_kit
    title 'Subscription Test Kit'
    description <<~DESCRIPTION
      The Subscriptions Test Suite verifies the conformance of systems to the FHIR Subscriptions
      framework as specified in the [HL7® FHIR® R5 version](https://www.hl7.org/fhir/R5/subscriptions.html)
      and above. For systems using the R4 and R4B releases of FHIR, it verifies Subscription
      functionality against the [Subscriptions R5 Backport
      IG](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/) that specifies how to use R5 Subscriptions
      functionality within those earlier versions.

      <!-- break -->

      ## Status

      These tests are a **DRAFT** intended to allow implementers to perform
      preliminary checks of their systems against Subscriptions capabilities backported
      from FHIR R5 to R4 and [provide feedback](https://github.com/inferno-framework/subscriptions-test-kit/issues)
      on the tests. Future versions of these tests may verify other
      requirements and may change the test verification logic. The test kit currently
      includes suites for systems implementing FHIR R4 only.

      ## Test Scope and Limitations

      The Subscriptions Test Kit includes suites for the following Subscriptions actors
      and versions:
      - **Subscriptions R4 Client Test Suite**:
        Verifies that a FHIR R4 system implements FHIR R5
        Subscriptions client capabilities as specified in the [Subscriptions R5 Backport
        IG](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/), namely the ability
        to request a Subscription and receive notifications.
      - **Subscriptions R4 Server Test Suite**:
        Verifies that a FHIR R4 system implements FHIR R5
        Subscriptions server capabilities as specified in the [Subscriptions R5 Backport
        IG](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/), namely the ability
        to receive Subscription requests and send notifications.

      Documentation of the current tests and their limitations can be found in each
      suite's description when the tests are run and can also be viewed in the
      source code:
      - [Subscriptions R4 Client Test Suite Documentation](https://github.com/inferno-framework/subscriptions-test-kit/blob/main/lib/subscriptions_test_kit/docs/dsubscriptions_r5_backport_r4_client_suite_description.md)
      - [Subscriptions R4 Server Test Suite Documentation](https://github.com/inferno-framework/subscriptions-test-kit/blob/main/lib/subscriptions_test_kit/docs/subscriptions_r5_backport_r4_server_suite_description.md)

      ### Test Scope

      To validate the behavior of the system under test, Inferno will act as an
      exchange partner. Specifically,

      - **When testing a Subscriptions client**: Inferno will simulate a Subscriptions
        server by responding to Subscription API requests (e.g., `create` interactions and
        the `$status` operation) and sending notifications as directed by
        created Subscription instances.
      - **When testing a Subscriptions server**: Inferno will simulate a Subscriptions
        client by requesting a Subscription with notifications delivered to an Inferno-hosted
        endpoint and responding to notifications sent to that endpoint by the server under test.

      ### Known Limitations

      This test kit is still in draft form and does not test all of the requirements and features
      described in the [R5 Subscriptions framework](https://www.hl7.org/fhir/R5/subscriptions.html)
      or its [backport to R4](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/).
      You can find information on the requirements that the test kit covers and does not cover in the [Requirements
      Coverage](https://github.com/inferno-framework/subscriptions-test-kit/blob/main/lib/subscriptions_test_kit/requirements/generated/subscriptions-test-kit_requirements_coverage.csv)
      CSV document.

      Specific current limitations to highlight include:
      - *Channels*: Inferno only supports the `rest-hook` notification delivery channel.
      - *Error Handling and Recovery*: Inferno does not test error handling and the ability
        to recover from errors or missed notifications, including the `$events` operation.
      - *Heartbeat Notifications*: Inferno will not send heartbeat notifications when simulating
        a Subscriptions server for the client test suite.
      - *FHIR Versions*: Inferno only supports verification of FHIR R4 systems.

      ## Reporting Issues

      Please report any issues with this set of tests in the [GitHub
      Issues](https://github.com/inferno-framework/subscriptions-test-kit/issues)
      section of the
      [open-source code repository](https://github.com/inferno-framework/subscriptions-test-kit).
    DESCRIPTION
    suite_ids [:subscriptions_r5_backport_r4_client, :subscriptions_r5_backport_r4_server]
    tags ['Subscriptions']
    last_updated LAST_UPDATED
    version VERSION
    maturity 'Low'
    authors ['Karl Naden', 'Emily Semple', 'Tom Strassner']
    repo 'https://github.com/inferno-framework/subscriptions-test-kit'
  end
end
