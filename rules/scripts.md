---
paths:
  - "scripts/**"
  - "bin/**"
  - "**/*.sh"
  - "**/Makefile"
  - "package.json"
---
<!-- overdoser-handbook rules/scripts.md, version 2026-11-07; copied verbatim, change it in the handbook. -->
# Scripts and CLIs

- Entry point: a `package.json` script, even for bash or Python. Name: `<subject>:<action>[:<variant>]` (`db:snapshot`,
  `docker:release:pull`, `ai:fix:docker`); standard verbs need no subject (`build`, `test`, `e2e`, `lint`, `build:web`).
  The file is the name with `-`: `scripts/db-snapshot.sh`.
- File paths given as arguments, inputs and outputs, are relative to the current folder (the project root under yarn),
  never to the script's folder. Only the script's own files come from `CLI_SCRIPT_DIR` / `run.scriptDir`.
- Three kinds. Read-only commands run directly. Commands that change things print a plan, then ask `Apply? [y/N]`.
  Destructive ones (restore, reset, drop) want the word `yes` typed.
- `-n` / `--dry-run` prints the plan only. `-y` / `--yes` applies without asking. Without a terminal (CI, pipes,
  agents) a changing command never asks: it prints the plan and exits with 3. As an agent, preview with `--dry-run`
  and apply with `--yes` only once the plan is right and the change was asked for.
- `--force` / `-f` only overrides a safety check; it never means "don't ask".
- `-h` / `--help` prints the header comment (what it does, usage, examples) and the options with their defaults.
- Options: `--name value`, `--name=value`, `-n value`, `-n=value`; `--no-flag`; lists repeat or use commas; `--` ends
  options. Every env setting also has a flag, and the flag wins.
- Common names: `-v --verbose`, `-q --quiet`, `--json`, `-e --env`, `-t --target`, `--all`, `--keep`, `-o --out`.
- Exit codes: 0 done or nothing to do, 1 failure, 2 usage error, 3 not applied (no terminal), 130 declined.
- Bash: `set -euo pipefail` and `scripts/lib/cli.sh`. Node: built-ins only and `scripts/lib/cli.mjs`. Python:
  `argparse` with `scripts/lib/cli.py`. Generators offer `--check` for CI.
- The `scripts/lib/` helpers are copies from `@overdoser/scripts`: never edit them; update with
  `npx @overdoser/scripts sync`, check with `--check`.
