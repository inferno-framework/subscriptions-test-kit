The Subscriptions R5 Backport IG v1.1.0 FHIR R4 Server Test Suite 
verifies the conformance of
server systems to the STU 1.1.0 version of the HL7® FHIR®
[Subscriptions R5 Backport IG](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/).

## Scope

These tests are a **DRAFT** intended to allow implementers to perform
preliminary checks of their systems against Subscriptions capabilities backported
from FHIR R5 to R4 and [provide feedback](https://github.com/inferno-framework/subscriptions-test-kit/issues)
on the tests. Future versions of these tests may verify other
requirements and may change the test verification logic.

## Test Methodology

For these tests Inferno simulates a Subscriptions client application. Inferno will subscribe
to certain updates on the server under test and wait for one or more notifications
indicating changes meeting those criteria. Using the interactions between Inferno and
the server under test, Inferno will verify that the server under test meets
the obligations from the implementation guide both on individual interactions
and in aggregate.

Over the course of a test session, Inferno may request multiple Subscriptions to verify
different features of the IG, e.g., different notification content types. Because the
choice of what topics and specific features to implement is left to individual servers,
Inferno does not dictate specific Subscription features or topics. Instead, the
tester will provide Subsription instances that Inferno will submit, modified lightly if needed, 
e.g., to point to Inferno's notification endpoint, to the server
as a part of the tests. In order for the tests to pass, the provided Subscription instances
must themselves be conformant and consistent with the notifications subsequently sent,
but no other requirements are placed on them, 
except those related to Inferno limitations (see the Current Limitations section below).

The content of all interactions sent by the server (responses and notifications), 
as well as tester-provided requests, will be checked 
for conformance to the Subscriptions IG requirements individually and used in 
aggregate to determine whether required features and functionality are present. 
HL7® FHIR® resources are checked for conformance using the Java validator with 
`tx.fhir.org` as the terminology server.

## Running the Tests

### Quick Start

The following inputs must be provided by the tester at a minimum to execute
any tests in this suite:
1. *FHIR Server Base URL*: The server's FHIR base URL. Inferno will use this when 
   performing Subscription creation requests and other interactions against the server
   under test.
1. *OAuth Credentials*: Auth credentials for Inferno to use when making requests against the 
   server under test. Specifically, Inferno will provide the *Access Token* input as a `Bearer`
   token in the `Authorization` header of HTTP requests. This input is not required if the server
   does not require authorization.
1. *Notification Access Token*: An access token that the server will send
   as a `Bearer` token in the `Authorization` header of HTTP notifications requests sent to Inferno. 
   Inferno uses the value to identify incoming requests that belong to the testing session.
1. *Workflow Subscription Resource*: A Subscription instance for Inferno to create on the server.
   Inferno will adjust it to be use the `rest-hook` channel and point to its notification endpoint.
   It must be conformant to the [R4/B Topic-Based Subscription profile](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription.html). 

Using these inputs, Inferno will perform a Subscription interaction loop with the server under test:
creating a Subscription, waiting for notifications, and then verifying the interactions. The tester will
be responsible for monitoring their system for the new Subscription from Inferno and performing
an action in their system that triggers an event notification to be sent to Inferno based on
that Subscription.

Additional inputs described in the *Additional Configuration Details* section below can enable
verification of additional content types and some Subscription creation error scenarios.

### Sample Execution

To try out these tests without a Subscriptions server implementation or performing steps to
generate an event notification, run them against the Subscriptions client test suite included
in this test kit. Related presets contain example Subscriptions and event notifications that
the test kits can use to interact. The client test suite can run a loop to simulate
a subscriptions server using the `rest-hook` channel type including responding to a
Subscription creation request and sending appropriate handshakes and notifications.

To run the server tests against the client tests:
1. Start an Inferno session of the Subscriptions Client test suite.
1. Select one of the *Inferno Subscription R4 Client [content type] Preset* from the Preset dropdown in the
   upper left.
1. Click the "Run All Tests" button in the upper right and click the "Submit" button in the dialog
   that appears. The simulated server will then be waiting for an interaction.
1. Start an Inferno session of the Subscriptions Server test suite.
1. Select the *[content type] Notifications Against The Subscriptions Client Suite* corresponding
   to the content type selected in the client test from the Preset dropdown in the upper left.
1. Click the "Run All Tests" button in the upper right and click the "Submit" button in the
   dialog that appears. The server tests make a Subscription request will and indicate that
   it is waiting for notifications to be made.
1. Wait 10-15 seconds while the client session makes requests, 
   then click the "Click here" link in the wait dialog to evaluate the notifications.
1. Back in the client session, click the "click here to complete the test" link
   and respond to the attestation
1. Meanwhile, the server tests will have completed and will be ready for review.

NOTE: Inferno uses the `Bearer` token sent in the `Authorization` HTTP header 
to associate requests with sessions. If multiple concurrent sessions are configured
to use the same token, they may interfere with each other. To prevent concurrent executors
of these sample executions from disrupting your session it
is recommended, but not required, to change all instances of `SAMPLE_TOKEN` in the
Inferno inputs for both client server suites (including within the Subscription instance body), 
to the same unique value so that the session will not interact with other concurrent users.

## Additional Configuration Details

The details provided here supplement the documentation of individual fields in the input dialog
that appears when initiating a test run.

### Subscriptions for other content types

To demonstrate the ability of the server under test to serve notifications of multiple different
content types, additional Subscription instances can be provided in one or more of the
following inputs:
- *Empty Notification Subscription Resource*
- *Id-Only Notification Subscription Resource*
- *Full-Resource Notification Subscription Resource*

When populated, Inferno will perform an interation loop with the server as a part of the 
*Notification Verification* test for the corresponding content type, including requesting that the
system under test create a Subscription for Inferno, waiting for notifications, and then
continuing with verification.

Additionally, if previously executed during this testing session, Inferno will include 
the Subscription interaction performed as a part of the *Demonstrate the Subscription
Workflow* group and verify is correctness as a part of the test for the content type
indicated in that Subscription. Thus, no additional Subscription needs to be provided
for the content type used in the *Workflow Subscription Resource* input.

Examples of Subscriptions that can be used in each of these inputs can be found within the
test kit source code:
- [`empty` Notification example](https://github.com/inferno-framework/subscriptions-test-kit/blob/main/subscriptions_test_kit/docs/samples/Subscription_empty.json)
- [`id-only` Notification example](https://github.com/inferno-framework/subscriptions-test-kit/blob/main/subscriptions_test_kit/docs/samples/Subscription_id-only.json)
- [`full-resource` Notification example](https://github.com/inferno-framework/subscriptions-test-kit/blob/main/subscriptions_test_kit/docs/samples/Subscription_full-resource.json)

### Unsupported Subscription creation element values

The Subscriptions Backport IG indicates that when accepting new Subscription creation requests
servers [*SHOULD* check the validity of serveral
elements](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/components.html#accepting-subscription-requests). 
Since which values are unsupported are specific to individual implementations, testers that wish
to verify that the system under test meets these requirements can provide specific values
in the following input fields:

- *Unsupported Subscription Topic*
- *Unsupported Subscription Filter*
- *Unsupported Subscription Channel Type*
- *Unsupported Subscription Channel Endpoint*
- *Unsupported Subscription Payload Type*
- *Unsupported Subscription Channel and Payload Combination*

In each case, Inferno will take the Subscription provided in the *Workflow Subscription Resource*
input, modify the corresponding element with the provided value, and expect that either the server
1. Rejects the Subscription, or
2. Changes the unsupported element value to something else that is supported

## Current Limitations

This test kit is still in draft form and does not test all of the requirements and features
described in the Subscriptions IG. You can find information on the requirements
that the test kit covers and does not cover in the [Requirements 
Coverage](lib/subscriptions_test_kit/requirements/generated/subscriptions-test-kit_requirements_coverage.csv)
CSV document.

Specific limitations to highlight include
- Inferno supports only the `rest-hook` channel type. Support for other channels may be added in the future.
  If there is a channel type that you would like to see verified, please 
  [provide feedback](https://github.com/inferno-framework/subscriptions-test-kit/issues) to that effect.
- Inferno does not test delivery error handling and recovery scenarios, including
  the optional `$events` API and event numbering details.