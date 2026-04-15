# Execution Scripts

Automated end-to-end scripts that drive the Inferno Subscriptions Test Kit using
the `inferno execute_script` CLI. They simulate a human tester running the suite
without any manual browser interaction.

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

Scripts use the built-in `inferno execute_script` framework: YAML configuration
files declare sessions, steps, and result comparison config. Complex interactions
that need local infrastructure (like the notification listener for client scripts)
are handled by a small Ruby command script invoked via the `command:` action.

---

## Files

| File | Suite | Payload | Sessions |
|------|-------|---------|----------|
| `subscriptions_r4_client_empty.yaml` | R4 Client | `empty` | Single |
| `subscriptions_r4_client_id_only.yaml` | R4 Client | `id-only` | Single |
| `subscriptions_r4_client_full_resource.yaml` | R4 Client | `full-resource` | Single |
| `subscriptions_r4_server_empty.yaml` | R4 Server + Client | `empty` | Multi |
| `subscriptions_r4_server_id_only.yaml` | R4 Server + Client | `id-only` | Multi |
| `subscriptions_r4_server_full_resource.yaml` | R4 Server + Client | `full-resource` | Multi |
| `client_interaction.rb` | Command script for client YAML scripts | — | — |

---

## Prerequisites

### Set up Inferno environment

https://inferno-framework.github.io/docs/getting-started/

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

**Client scripts:**
```bash
bundle exec inferno execute_script execution_scripts/subscriptions_r4_client_empty.yaml --allow-commands
```
```bash
bundle exec inferno execute_script execution_scripts/subscriptions_r4_client_id_only.yaml --allow-commands
```
```bash
bundle exec inferno execute_script execution_scripts/subscriptions_r4_client_full_resource.yaml --allow-commands
```

**Server scripts:**
```bash
bundle exec inferno execute_script execution_scripts/subscriptions_r4_server_empty.yaml --allow-commands
```
```bash
bundle exec inferno execute_script execution_scripts/subscriptions_r4_server_id_only.yaml --allow-commands
```
```bash
bundle exec inferno execute_script execution_scripts/subscriptions_r4_server_full_resource.yaml --allow-commands
```

> The `--allow-commands` flag is required because the client scripts use `command:` actions.
> The server scripts use `command:` actions too (curl for URL clicks). All scripts require it.


## How the Client Scripts Work

The three client scripts (empty, id-only, full-resource) follow the same flow.
They act as the **FHIR client under test**.

```
[created]   → start_run: suite
              Starts the full client suite test run.

[waiting]   → last_completed: subscriptions_r4_client_interaction
  command:    bundle exec ruby execution_scripts/client_interaction.rb ...
              The client_interaction.rb script:
                1. Starts a TCPServer on a random local port (responds 200 to
                   everything — receives Inferno's handshake and event notifications)
                2. POSTs a conformant Subscription to Inferno's FHIR endpoint
                   with the payload type for this script
                3. Sleeps 20s for Inferno's SendSubscriptionNotifications job
                   to deliver handshake + event notification to the listener
                4. GETs the confirmation_url to advance the InteractionTest wait

[waiting]   → last_completed: subscriptions_r4_client_processing_attestation
  command:    curl -s '{wait_outputs.attest_true_url}'
              Equivalent to a human clicking "true" in the UI.

[done]      → END_SCRIPT
```

### Payload type differences

The only difference between the three client YAML files is the preset and the
`payload_code` argument passed to `client_interaction.rb`:

| Script | Preset | `payload_code` |
|--------|--------|----------------|
| `empty` | `...client_empty` | `empty` |
| `id_only` | `...client_id_only` | `id-only` |
| `full_resource` | `...client_full_resource` | `full-resource` |

---

## How the Server Scripts Work

The three server scripts (empty, id-only, full-resource) follow the same flow.
They orchestrate **two sessions**: a client session and a server session. The
client session is required because `SubscriptionCreateEndpoint` (which the server
suite uses to POST its Subscription) requires an active waiting client test run
to exist before it will accept the request.

```
[client: created]   → start_run: client suite
                      Starts the full client suite. Poll client.

[client: waiting]   → last_completed: subscriptions_r4_client_interaction
  start_run:          server suite
  next_poll:          server
                      Client is now at InteractionTest wait. Start the server
                      suite. The server suite POSTs a Subscription to the client
                      suite's FHIR endpoint, which triggers
                      SendSubscriptionNotifications to deliver handshake + event
                      notifications back to the server suite's listener.

[server: waiting]   → last_completed: subscriptions_r4_server_notification_delivery
  command:            sleep 20 && curl -s '{server.wait_outputs.confirmation_url}'
  next_poll:          server
                      Wait for notifications to land, then advance the server wait.

[server: done]      → last_completed: suite
  command:            curl -s '{client.wait_outputs.confirmation_url}'
  next_poll:          client
                      Server suite complete. Advance the client's InteractionTest
                      wait so the client can run its post-interaction verification
                      tests.

[client: waiting]   → last_completed: subscriptions_r4_client_processing_attestation
  command:            curl -s '{client.wait_outputs.attest_true_url}'
  next_poll:          client

[client: done]      → END_SCRIPT
```

---

## Result Comparison

On first run the framework auto-creates an expected results file
(`<script_name>_expected.json`) and exits with a non-zero code. Re-run the
script to compare against it.

The `comparison_config` in each YAML normalises:
- The Inferno host URL (replaced with `<INFERNO_HOST>`)
- UUIDs (replaced with `<UUID>`)

This ensures results are comparable across different runs and machines.
