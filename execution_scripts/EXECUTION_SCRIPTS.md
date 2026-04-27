# Execution Scripts

Automated end-to-end scripts that drive the Inferno Subscriptions Test Kit
using the `inferno execute_script` CLI. They simulate a human tester running
the suite without any manual browser interaction.

For general background on the `execute_script` framework, see the
[Scripting Suite Execution](https://inferno-framework.github.io/docs/advanced-test-features/scripting-execution.html)
documentation. For CLI usage and how to start Inferno and run scripts, see the
[Inferno CLI](https://inferno-framework.github.io/docs/getting-started/inferno-cli#complex-scripted-execution)
documentation.

---

## Files

| File | Payload |
|------|---------|
| `subscriptions_r4_empty_with_commands.yaml` | `empty` |
| `subscriptions_r4_id_only_with_commands.yaml` | `id-only` |
| `subscriptions_r4_full_resource_with_commands.yaml` | `full-resource` |
| `advance_wait.rb` | Shared helper — advances an Inferno wait state via GET |

Run a script from the repository root:

```bash
bundle exec inferno execute_script execution_scripts/subscriptions_r4_empty_with_commands.yaml --allow-commands
```
```bash
bundle exec inferno execute_script execution_scripts/subscriptions_r4_id_only_with_commands.yaml --allow-commands
```
```bash
bundle exec inferno execute_script execution_scripts/subscriptions_r4_full_resource_with_commands.yaml --allow-commands
```

The `_with_commands` suffix signals to the `execute_scripts:run_all` Rake task
and the GitHub Actions workflow that these scripts require the `--allow-commands`
flag, which is passed automatically.

---

## Result Comparison

For general documentation on how result comparison works, see
[Check Results](https://inferno-framework.github.io/docs/advanced-test-features/scripting-execution#check-results).

Each script normalises the following values before comparison so that results
are portable across runs and Inferno instances:
- The Inferno host URL (replaced with `<INFERNO_HOST>`)
- UUIDs (replaced with `<UUID>`)
