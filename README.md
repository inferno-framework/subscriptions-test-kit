# FHIR Subscriptions Test Kit

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

This test kit is [open source](#license) and freely available for use or
adoption by the health IT community including EHR vendors, health app
developers, and testing labs. It is built using the [Inferno
Framework](https://inferno-framework.github.io/). The Inferno Framework is
designed for reuse and aims to make it easier to build test kits for any
FHIR-based data exchange.

## Status

These tests are a **DRAFT** intended to allow Subscriptions implementers to perform 
preliminary checks of their implementations against Subscription R5 Backport IG's requirements
and provide feedback on the tests. Future versions of these tests may verify other 
requirements and may change how these are tested.

## Test Scope and Limitations

This test is still in draft form and does not test all of the requirements and features
described in the Subscriptions IG. You can find information on the requirements
that the kit covers and does not cover in the [Requirements 
Coverage](lib/subscriptions_test_kit/requirements/generated/subscriptions-test-kit_requirements_coverage.csv)
CSV document.

Specific limitations to highlight include
- Inferno supports only the `rest-hook` channel type. Support for other channels may be added in the future.
  If there is a channel type that you would like to see verified, please 
  [provide feedback](https://github.com/inferno-framework/subscriptions-test-kit/issues) to that effect.
- Inferno does not test delivery error handling and recovery scenarios, including
  the optional `$events` API and event numbering details.
- Inferno only supports verification of FHIR R4 systems.

See suite-specific documentation on scope and current limitations
for R4 [server](lib/subscriptions_test_kit/docs/subscriptions_r5_backport_r4_server_suite_description.md) and R4
[client](lib/subscriptions_test_kit/docs/subscriptions_r5_backport_r4_client_suite_description.md)
tests.

## How to Run

Use either of the following methods to run the suites within this test kit.
If you would like to try out the tests but don’t have a Subscriptions implementation, 
the test home pages include instructions for trying out the tests by running the 
client and server suites against each other

Detailed instructions can be found in the suite descriptions when the tests
are run or within this repository for 
[server](lib/subscriptions_test_kit/docs/subscriptions_r5_backport_r4_server_suite_description.md#running-the-tests) and
[client](lib/subscriptions_test_kit/docs/subscriptions_r5_backport_r4_client_suite_description.md#running-the-tests)
tests, including [instructions for running the test kits against each 
other](lib/subscriptions_test_kit/docs/subscriptions_r5_backport_r4_client_suite_description.md#sample-execution)
to see the tests work without bringing an implementation.

### ONC Hosted Instance

You can run the Subscriptions test kit via the [ONC Inferno](https://inferno.healthit.gov/test-kits/subscriptions/)
website by choosing the “Subscriptions Test Kit” test kit.

### Local Inferno Instance

- Download the source code from this repository.
- Open a terminal in the directory containing the downloaded code.
- In the terminal, run `setup.sh`.
- In the terminal, run `run.sh`.
- Use a web browser to navigate to `http://localhost`.

NOTE: running the client and server tests against each other does not work
when running the test kit locally using Docker. If you'd like to use the demo,
use the [public instance](https://inferno.healthit.gov/test-kits/subscriptions/)
or [run locally using Ruby](#development).

## Providing Feedback and Reporting Issues

We welcome feedback on the tests, including but not limited to the following areas:
- Verification logic, such as potential bugs, lax checks, and unexpected failures.
- Requirements coverage, such as requirements that have been missed and tests that necessitate features that the IG does not require.
- User experience, such as confusing or missing information in the test UI.

Please report any issues with this set of tests in the issues section of this repository.

## Development

To make updates and additions to this test kit, see the 
[Inferno Framework Documentation](https://inferno-framework.github.io/docs/),
particularly the instructions on 
[development with Ruby](https://inferno-framework.github.io/docs/getting-started/#development-with-ruby).

## Requirements Tracking and Test Coverage

This test kit includes experimental capabilities to document which tests verify which requirements
and create a document outlining the coverage of the requirements by the test kit. The functionality
is currently specific to the Subscriptions test kit and will be generalized and expanded in the future.

### Related Files

The following files are involved in the requirements tracking and test coverage functionality
and are all located in the `requirments` folder or sub-folders:
- [`subscriptions-test-kit_requirements.csv`](lib/subscriptions_test_kit/requirements/subscriptions-test-kit_requirements.csv): contains
  the full list of requirements extracted and in scope for this test kit. This can either be created by hand
  or generated from a set of requirements planning excel documents.
- [`subscriptions-test-kit_out_of_scope_requirements.csv`](lib/subscriptions_test_kit/requirements/subscriptions-test-kit_out_of_scope_requirements.csv):
  contains a list of requirements that will not be tested due to the inability to verify
  the requirement or other reasons. This can either be created by hand
  or generated from a set of requirements planning excel documents.
- [`subscriptions-test-kit_requirements_coverage.csv`](lib/subscriptions_test_kit/requirements/generated/subscriptions-test-kit_requirements_coverage.csv):
  this generated file contains the list of requirements and which tests in which suites test them. Requirements that
  are not pertinent to the actor each suite tests are indicated, as are requirements that are explicitly listed in the
  [`subscriptions-test-kit_out_of_scope_requirements.csv`](lib/subscriptions_test_kit/requirements/subscriptions-test-kit_out_of_scope_requirements.csv)
  file.

### Inferno DSL Annotations

This test kit includes an extension that allows the `verifies_requirements` field 
within Inferno Suites, Groups, and Tests to be populated with a comma-seperated
list of requirement identifiers that correspond to rows in the 
[`subscriptions-test-kit_requirements.csv`](lib/subscriptions_test_kit/requirements/subscriptions-test-kit_requirements.csv) file, either in the form `'<requirement set id>@<requiment id>'`.

Including a requirement within the `verifies_requirements` list asserts that execution of the test, group, or suite
verifies the referenced requirement and a pass indicates that the system meets the requirement. At this time,
there is no way to indicate that the verification is partial.

### Rake Tasks

Two rake tasks can be used to generate the files described above:
- `bundle exec rake "requirements:collect[<path to directory with planning excel file(s)>]"`:
  This task converts one or more requirements planning files into the
  [`subscriptions-test-kit_requirements.csv`](lib/subscriptions_test_kit/requirements/subscriptions-test-kit_requirements.csv) and
  [`subscriptions-test-kit_out_of_scope_requirements.csv`](lib/subscriptions_test_kit/requirements/subscriptions-test-kit_out_of_scope_requirements.csv)
  files.
    - NOTE: an issue with this task can cause the links the the `URL` column to be truncated in
      a valid, but not ideal way. check for changes of this nature before committing updates
      to the [`subscriptions-test-kit_requirements.csv`](lib/subscriptions_test_kit/requirements/subscriptions-test-kit_requirements.csv) file. To avoid the issue, make sure that in the 
      source excel files the `URL` column has no hyperlinks by selecting the column, right clicking,
      and selecting "Remove Hyperlinks". If that menu option is not present, there are no hyperlinks
      present. Once you have confirmed that no hyperlinks are present, run the collect script.
- `bundle exec rake requirements:generate_coverage`: This task uses the information in the
  [`subscriptions-test-kit_requirements.csv`](lib/subscriptions_test_kit/requirements/subscriptions-test-kit_requirements.csv) file, the
  [`subscriptions-test-kit_out_of_scope_requirements.csv`](lib/subscriptions_test_kit/requirements/subscriptions-test-kit_out_of_scope_requirements.csv)
  file, and the `verifies_requirements` annotations in the test kit to create the
  [`subscriptions-test-kit_requirements_coverage.csv`](lib/subscriptions_test_kit/requirements/generated/subscriptions-test-kit_requirements_coverage.csv) file.

Each has a corresponding "check" rake task (`requirements:check_collection` and 
`"requirements:check_coverage[<path to directory with planning excel file(s)>]"`) that
can be built into commit pipelines to ensure that the files are in sync with the other content.

## License

Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License. You may obtain a copy of the
License at
```
http://www.apache.org/licenses/LICENSE-2.0
```
Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.

## Trademark Notice

HL7, FHIR and the FHIR [FLAME DESIGN] are the registered trademarks of Health
Level Seven International and their use does not constitute endorsement by HL7.