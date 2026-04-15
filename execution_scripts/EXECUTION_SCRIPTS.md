# Execution Scripts

Automated end-to-end scripts that drive the Inferno Subscriptions Test Kit using
the `inferno execute_script` CLI. They simulate a human tester running the suite
without any manual browser interaction.

---

## Overview

The Inferno UI requires a human to perform two types of manual steps during a
test run:

1. **Interaction steps** — clicking a confirmation URL to advance a wait state.
2. **Attestation steps** — clicking a URL to confirm that a notification was
   processed correctly.

These scripts replace those manual steps with API calls, allowing the full suite
to run unattended.

Each script orchestrates **two sessions** — a client session and a server
session. The server suite acts as the FHIR client under test: it POSTs a
Subscription to the client suite's FHIR endpoint, and the client suite delivers
handshake and event notifications back to the server suite's own notification
endpoint.

Scripts use the built-in `inferno execute_script` framework: YAML configuration
files declare sessions, steps, and result comparison config. Wait state
advancement is handled by `advance_wait.rb`, a small Ruby helper invoked via the
`command:` action.

---

## Files

| File | Payload |
|------|---------|
| `subscriptions_r4_empty_with_commands.yaml` | `empty` |
| `subscriptions_r4_id_only_with_commands.yaml` | `id-only` |
| `subscriptions_r4_full_resource_with_commands.yaml` | `full-resource` |
| `advance_wait.rb` | Shared helper — advances an Inferno wait state via GET |

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

If port 4567 is already in use from a previous run:

```bash
lsof -ti :4567 | xargs kill -9
```

---

## Running the Scripts

Open a second terminal and from the repository root:

```bash
bundle exec inferno execute_script execution_scripts/subscriptions_r4_empty_with_commands.yaml --allow-commands
```
```bash
bundle exec inferno execute_script execution_scripts/subscriptions_r4_id_only_with_commands.yaml --allow-commands
```
```bash
bundle exec inferno execute_script execution_scripts/subscriptions_r4_full_resource_with_commands.yaml --allow-commands
```

> The `--allow-commands` flag is required because the scripts use `command:` actions. The
> `_with_commands` suffix in the filename signals this to the `execute_scripts:run_all` Rake task
> and the GitHub Actions workflow, which pass the flag automatically.

---

## How the Scripts Work

All three scripts follow the same flow, differing only in the preset names used
for each session.

```
[client: created]   → start_run: client suite
                      Starts the client suite. Client runs until it reaches the
                      InteractionTest wait, where it is ready to receive a
                      Subscription from the server under test.

[client: waiting]   → last_completed: 1.1.01
  start_run:          server suite
  next_poll:          server
                      Client is at InteractionTest (1.1.01). Start the server
                      suite. The server suite POSTs a Subscription to the
                      client's FHIR endpoint. The client then delivers handshake
                      and event notifications to the server suite's own
                      notification endpoint inside Inferno.

[server: waiting]   → last_completed: 1.1.02
  command:            advance_wait.rb '{server.wait_outputs.confirmation_url}' 15
  next_poll:          server
                      Server is at notification delivery wait (1.1.02). Sleep
                      15s for the client to finish delivering notifications,
                      then advance the server wait.

[server: done]      → last_completed: suite
  command:            advance_wait.rb '{client.wait_outputs.confirmation_url}'
  next_poll:          client
                      Server suite complete. Advance the client's InteractionTest
                      wait so it can continue with conformance verification.

[client: waiting]   → last_completed: 1.3.04
  command:            curl -s '{client.wait_outputs.attest_true_url}'
  next_poll:          client
                      Client is at processing attestation (1.3.04). Attest that
                      the event notification was processed correctly.

[client: done]      → END_SCRIPT
```

### Payload type differences

The only difference between the three YAML files is the preset used for each
session:

| Script | Client preset | Server preset |
|--------|--------------|---------------|
| `subscriptions_r4_empty_with_commands.yaml` | `...client_empty` | `...server_preset_empty` |
| `subscriptions_r4_id_only_with_commands.yaml` | `...client_id_only` | `...server_preset_id_only` |
| `subscriptions_r4_full_resource_with_commands.yaml` | `...client_full_resource` | `...server_preset_full_resource` |

---

## Result Comparison

On first run the framework auto-creates expected results files
(`<script_name>_client_expected.json` and `<script_name>_server_expected.json`)
and exits. Re-run the script to compare against them.

The `comparison_config` in each YAML normalises:
- The Inferno host URL (replaced with `<INFERNO_HOST>`)
- UUIDs (replaced with `<UUID>`)

This ensures results are comparable across different runs and machines.

When results differ, a CSV diff report is generated alongside the expected files
showing which tests changed, what their previous and current results were, and
any differences in validator messages.
