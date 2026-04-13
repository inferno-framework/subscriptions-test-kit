# Execution Scripts

Automated end-to-end scripts that drive the Inferno Subscriptions Test Kit via
its REST API, simulating a human tester without manual browser interaction.

---

## Overview

The Inferno UI requires a human to perform two types of manual steps during a
test run:

1. **Interaction steps** — e.g. POSTing a Subscription to Inferno's FHIR
   endpoint, or clicking a confirmation URL to advance a wait state.
2. **Attestation steps** — e.g. clicking a URL to confirm that a notification
   was processed correctly.

These scripts replace those manual steps with API calls, allowing
the full suite to run unattended.

---

## Files

| File | Suite | Payload |
|------|-------|---------|
| `subscriptions_r4_client_empty.rb` | R4 Client | `empty` |
| `subscriptions_r4_client_id_only.rb` | R4 Client | `id-only` |
| `subscriptions_r4_client_full_resource.rb` | R4 Client | `full-resource` |
| `subscriptions_r4_server_empty.rb` | R4 Server | `empty` |
| `subscriptions_r4_server_id_only.rb` | R4 Server | `id-only` |
| `subscriptions_r4_server_full_resource.rb` | R4 Server | `full-resource` |
| `run_script_helper.rb` | Shared helper module | — |

---

## Changes Made to the Codebase

### New files added

- `execution_scripts/run_script_helper.rb` — shared helper module included by
  all scripts
- `execution_scripts/subscriptions_r4_client_empty.rb`
- `execution_scripts/subscriptions_r4_client_id_only.rb`
- `execution_scripts/subscriptions_r4_client_full_resource.rb`
- `execution_scripts/subscriptions_r4_server_empty.rb`
- `execution_scripts/subscriptions_r4_server_id_only.rb`
- `execution_scripts/subscriptions_r4_server_full_resource.rb`

### Gemfile

No changes required to Gemfile
---

## Prerequisites

### `foreman`

`bundle exec inferno start` uses foreman to start Puma and Sidekiq together.
Install it as a system gem (not in the bundle):

```bash
gem install foreman
```

---

## Starting Inferno

Run these in order:

```bash
bundle exec inferno services start
```
```bash
bundle exec inferno start
```

> **Developer mode required for client scripts:** Inferno must be running
> directly on your machine (not inside Docker) so that its background jobs can
> reach `localhost` on the notification listener port. `bundle exec inferno
> start` satisfies this.

If port 4567 is already in use from a previous run:

```bash
lsof -ti :4567 | xargs kill -9
```

---

## Running the Scripts

Open a second terminal and from the repository root:

Preset 1 test: client empty preset
```bash
bundle exec ruby execution_scripts/subscriptions_r4_client_empty.rb
```
Preset 2 test: client id only preset
```bash
bundle exec ruby execution_scripts/subscriptions_r4_client_id_only.rb
```
Preset 3 test: client full resource preset
```bash
bundle exec ruby execution_scripts/subscriptions_r4_client_full_resource.rb
```

## How the Client Scripts Work

The three client scripts are identical except for their preset ID and payload
type. They act as the **FHIR client under test**.

```
[1/7] Start notification listener
      Starts a minimal TCPServer on a random port in a background thread.
      It responds HTTP 200 to every request. This is the endpoint Inferno
      will POST handshake and event notifications to.

[2/7] Create test session
      POST /api/test_sessions with the suite ID and preset ID.
      The preset loads access_token (SAMPLE_TOKEN) and the
      notification_bundle input for the chosen payload type.

[3/7] Start test run
      POST /api/test_runs. Session data is passed as inputs to satisfy
      Inferno's required-input validation.

[4/7] Wait for subscription interaction wait state
      The InteractionTest pauses and waits for a Subscription POST.
      The script polls GET /api/test_runs/:id every 2s until status == "waiting",
      then POSTs a conformant FHIR Subscription to:
        /custom/subscriptions_r5_backport_r4_client/fhir/Subscription
      with Authorization: Bearer SAMPLE_TOKEN.

      Inferno's SendSubscriptionNotifications background job then POSTs a
      handshake followed by an event notification to the TCPServer listener.
      The script sleeps 20s to allow both deliveries to complete.

[5/7] Advance the interaction wait
      Fetches confirmation_url from session data and GETs it. This resumes
      the test run. Inferno then automatically runs the handshake and event
      notification verification tests.

[6/7] Wait for attestation wait state
      ProcessingAttestationTest pauses and waits for the tester to confirm
      the event notification was processed correctly. The script fetches
      attest_true_url from session data and GETs it — equivalent to a human
      clicking "true" in the UI.

[7/7] Wait for completion
      Polls until the run reaches "done", then prints a pass/fail summary.
```

### Payload type differences

The only difference between the three client scripts is:

| Script | `PRESET_ID` | `PAYLOAD_CODE` |
|--------|-------------|----------------|
| `empty` | `...client_empty` | `"empty"` |
| `id_only` | `...client_id_only` | `"id-only"` |
| `full_resource` | `...client_full_resource` | `"full-resource"` |

`PRESET_ID` controls which `notification_bundle` fixture is loaded as input.
`PAYLOAD_CODE` sets the `backport-payload-content` extension value in the
Subscription that gets POSTed to Inferno.

### Payload type meanings

| Type | What Inferno includes in the event notification |
|------|-------------------------------------------------|
| `empty` | Status parameters only — no resource data |
| `id-only` | Status parameters + resource ID reference |
| `full-resource` | Status parameters + complete resource inline |

---

## How the Server Scripts Work

> **These scripts are not recommended for use yet.** See Known Issues below.

The server scripts act as the **FHIR server under test**. In the server suite,
Inferno acts as the client — it POSTs a Subscription to the "server under test"
and expects to receive handshake and event notifications back.

The server presets point Inferno's `url` at the **client suite's** FHIR
endpoint (`/custom/subscriptions_r5_backport_r4_client/fhir/Subscription`).
The client suite's `SubscriptionCreateEndpoint` then kicks off the
`SendSubscriptionNotifications` job, which delivers notifications back to the
server suite's listener.

```
[1/5] Create test session with server preset
[2/5] Start test run
[3/5] Wait for notification delivery wait state
      Sleep 20s for notifications to be delivered
[4/5] Advance wait state via confirmation_url
[5/5] Wait for completion
```

---

## Known Issues

### 1. Server scripts — missing client session (blocker)

**Status:** Not safe to run.

The `SubscriptionCreateEndpoint` (the client suite's FHIR endpoint that accepts
Subscription POSTs) requires an active, waiting client suite test run to exist
with identifier `SAMPLE_TOKEN` before it will accept a request. It uses this
to look up which `notification_bundle` to send and which session to associate
the request with.

The server scripts currently only create a server session. When Inferno's server
suite test POSTs the Subscription, the endpoint finds no waiting client run and
returns HTTP 500. The server suite's `send_subscription` method then asserts a
201 response, which fails, and the test run errors out before reaching the
notification delivery wait state.

**Fix required:** The server scripts need to be redesigned to:
1. Create a **client** session and start a client test run
2. Wait for the client's `InteractionTest` to enter `waiting` status
3. Then create the server session and start the server test run
4. Orchestrate both runs through to completion

### 2. `ProcessingAttestationTest` — undefined variable `token` (blocker for client scripts)

**Status:** Pre-existing bug in the test kit, not introduced by the scripts.

In `lib/subscriptions_test_kit/suites/subscriptions_r5_backport_r4_client/workflow/conformance_verification/processing_attestation_test.rb`,
the `wait()` message interpolates `#{token}` on lines 38 and 40, but `token`
is never defined. The variable defined above it is `identifier` (set to
`test_session_id`). Ruby raises `NameError` at runtime, crashing the test
before it enters the wait state. The test run completes as `done/error` at step
6 instead of pausing for attestation.

**Fix:** Change both occurrences of `#{token}` to `#{identifier}` in
`processing_attestation_test.rb`.

---

## Helper Module Reference (`run_script_helper.rb`)

All scripts include `RunScriptHelper` which provides:

| Method | Description |
|--------|-------------|
| `inferno_base_url` | Returns `INFERNO_BASE_URL` env var or `http://localhost:4567` |
| `create_session(suite_id, preset_id)` | Creates a session and applies a preset |
| `start_test_run(session_id, suite_id)` | Starts a full suite test run with session inputs |
| `get_test_run(id)` | Fetches current test run status |
| `get_session_data(session_id)` | Returns all session inputs/outputs as a name→value hash |
| `wait_for_waiting_state(id)` | Polls until status == `"waiting"`, raises on timeout or early completion |
| `wait_for_completion(id)` | Polls until status == `"done"` |
| `fetch_output(session_id, name)` | Reads a named output from session data, raises if missing |
| `http_get(url)` | GETs a URL — used to click confirmation/attestation URLs |
| `http_post_fhir(url, body, token)` | POSTs a FHIR resource with a Bearer token |
| `start_notification_listener` | Starts a TCPServer on a random port, returns `[server, thread, port]` |
| `stop_notification_listener(server, thread)` | Shuts down the listener |
| `build_subscription(endpoint, payload_code)` | Builds a conformant FHIR Subscription JSON body |
| `assert_all_tests_passed(run_id, session_id, suite_id)` | Prints result summary, raises if any test failed/errored |

### Timing constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `POLL_INTERVAL` | 2s | Delay between status poll requests |
| `DEFAULT_TIMEOUT` | 120s | Max time to wait for a status change |
| `NOTIFICATION_DELAY` | 20s | Sleep time to allow `SendSubscriptionNotifications` to complete |
