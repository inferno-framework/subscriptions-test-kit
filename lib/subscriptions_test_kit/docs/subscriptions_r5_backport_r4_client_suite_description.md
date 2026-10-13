The Subscriptions R5 Backport IG v1.1.0 FHIR R4 Client Test Suite 
verifies the conformance of
client systems to the STU 1.1.0 version of the HL7® FHIR®
[Subscriptions R5 Backport IG](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/).

## Scope

These tests are a **DRAFT** intended to allow implementers to perform
preliminary checks of their systems against Subscriptions capabilities backported
from FHIR R5 to R4 and [provide feedback](https://github.com/inferno-framework/subscriptions-test-kit/issues)
on the tests. Future versions of these tests may verify other
requirements and may change the test verification logic.

## Test Methodology

For these tests Inferno simulates a Subscriptions server application. The client contains
two groups:
- *Demonstrate the Rest-Hook Subscription Workflow*, which tests the client's ability to
  create a Subscription using the rest-hook channel and receive notifications based on it.
- *Demonstrate Subscription Update and Deletion*, which tests the client's ability to
  update and delete the Subscription created during the first group.

During each group, Inferno will wait for the client system to make requests against Inferno.
Inferno will react to those requests, triggering handshakes and notifications. 
Using the interactions between Inferno and the client system, Inferno will verify that
the client meets the obligations from the implementation guide both on individual interactions
and in aggregate.

Inferno does not implement a real data repository that recognizes resource-level changes.
So, for the first group, Inferno relies on the tester to provide an event notification that
Inferno will send back to the client system. Inferno will manipulate this provided
notification to generate other notifications, such as handshakes and `$status` operation
responses, to send and respond with as directed by the IG. Inferno will verify that the
provided event notification is conformant and that it matches the requirements for the
Subscription sent by the client system.

The content of all Subscription interactions sent by the client, 
as well as tester-provided notifications, will be checked 
for conformance to the Subscriptions IG requirements individually and used in 
aggregate to determine whether required features and functionality are present. 
HL7® FHIR® resources are checked for conformance using the Java validator with 
`tx.fhir.org` as the terminology server.

## Running the Tests

### Quick Start

The following inputs must be provided by the tester at a minimum to execute
any tests in this suite:
1. *Access Token*: A `Bearer` token that the client system will send in the 
   `Authorization` header of HTTP requests made against Inferno. Inferno uses the
   value to identify incoming requests that belong to the testing session.
1. *Notification Bundle*: an `event-notification` conforming to the [R4 Topic-Based
   Subscription Notification Bundle profile](https://hl7.org/fhir/uv/subscriptions-backport/STU1.1/StructureDefinition-backport-subscription-notification-r4.html).
   Inferno uses this as the basis for responses and notifications that it will send
   to the client.

All other details needed to interact with the client system, such as where to send notifications,
will be determined from the subscription that the client will create. Once the testing start,
Inferno will wait for a Subscription creation request and then send the relevant handshakes
and notification requests to the client and verify the interaction.

Additional inputs described in the *Additional Configuration Details* section below can enable
verification of additional content types and some Subscription creation error scenarios.

### Sample Execution

To try out these tests without a Subscriptions client implementation or performing steps to
create a Subscription, run them against the Subscriptions server test suite included
in this test kit. Related presets contain example Subscriptions and event notifications that
the test kits can use to interact. The server test suite can simulate
a subscriptions client creating a `rest-hook` Subscription responding to appropriate handshakes
and notifications.

To run the client tests against the server tests:
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
   and respond to the attestation based on the results in the server session.
1. The client session will then wait for the Subscription to be updated and deleted. The server
   session's *Subscription Update and Deletion Verification* tests have already made these requests,
   but they will have failed as Inferno only accepts these interactions when made during this test.
   Return to the server session and re-run the *Subscription Update and Deletion Verification*
   group.
1. Once the server run has completed, return to the client session and click the "click here to
   complete the test" link and review the results.

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

### Client Notification Access Token

If the client system needs Inferno to send a specific `Bearer` token in the HTTP `Authorization` header
when sending notifications and it cannot be specified in the `channel.header` element of the Subscription
instance that the client sends to Inferno, then a value can be provided here.

## Current Limitations

This test kit is still in draft form and does not test all of the requirements and features
described in the Subscriptions IG. You can find information on the requirements
that the test kit covers and does not cover in the [Requirements 
Coverage](https://github.com/inferno-framework/subscriptions-test-kit/blob/main/lib/subscriptions_test_kit/requirements/generated/subscriptions-test-kit_requirements_coverage.csv)
CSV document.

Specific limitations to highlight include:
- Inferno supports only the `rest-hook` channel type. Support for other channels may be added in the future.
  If there is a channel type that you would like to see verified, please 
  [provide feedback](https://github.com/inferno-framework/subscriptions-test-kit/issues) to that effect.
- Inferno does not test delivery error handling and recovery scenarios, including
  the optional `$events` API and event numbering details.
- Inferno does not support sending heartbeat notifications.
- Inferno does not verify that the shape and content of notifications are appropriate for the triggering
  Subscription because those details, e.g., the resource types that can be a focus of the notification, 
  are defined within the SubscriptionTopic which is not available in FHIR R4.
- When sending notifications, Inferno supports only JSON payloads and will always use `application/fhir+json`
  as the value of the `content-type` HTTP header, unless the client system explicitly asks for
  `application/json` using the `Subscription.channel.payload` element.
- Inferno supports Subscription `PATCH` requests only when they use JSON Patch. XML Patch and FHIRPath Patch
  are not supported.
- Inferno does not support re-creating a deleted Subscription with a `PUT` request. Once the client deletes the
  Subscription, Inferno responds to `PUT` and `PATCH` requests for it with `404 Not Found`, and the update
  conformance verification tests will report those requests as failures.
- Inferno records each request it receives just after responding to it, and its simulated Subscription reflects
  only the requests it has recorded. As a result, a request sent immediately after an update or delete, for
  example in parallel or over a separate connection, may be answered as if that change had not happened yet.
  If Inferno's responses appear inconsistent with earlier changes, pause briefly between requests.
