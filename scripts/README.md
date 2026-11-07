# Scripts and CLIs

One way to write project scripts, in any language, so every command behaves the same: you can run a read-only one
right away, a changing one always shows what it will do first, and `--help` always tells you how to use it.
Short form for agents: [rules/scripts.md](../rules/scripts.md). Working, tested examples: [examples/](examples/README.md).

## Entry point

- Every command a person or agent runs is a `package.json` script, also in projects whose scripts are bash or Python:
  `yarn db:restore`, `yarn docker:release`. One place to discover commands, and arguments pass straight through
  (with npm, after `--`: `npm run db:restore -- --dry-run`).
- The script file lives in `scripts/`; shared helpers in `scripts/lib/`.

## Names

A name says what it works on, then what it does: `<subject>:<action>`, or `<subject>:<action>:<variant>` when there
are several ways to do it.

| Name | Subject | Action | Variant |
|---|---|---|---|
| `db:snapshot` | db | snapshot | |
| `pgp:generate` | pgp | generate | |
| `docker:release` | docker | release | |
| `docker:release:pull` | docker | release | pull |
| `ai:run` | ai | run | |
| `ai:fix:docker` | ai | fix | docker |

- **Standard verbs need no subject.** Commands that act on the whole project keep their usual short names, and take
  a variant when there are several: `build`, `dev`, `start`, `test`, `e2e`, `lint`, `typecheck`, `format`, `clean`,
  `build:web`, `dev:api`.
- **Subject:** a noun for the thing worked on: `db`, `docker`, `prod`, `logs`, `docs`, `user`, `ai`. An environment
  can be the subject when the command manages that stack: `prod:start`, `prod:logs`.
- **Action:** a verb, from the common set where one fits: `start`, `stop`, `logs`, `status`, `generate`, `migrate`,
  `seed`, `snapshot`, `restore`, `export`, `import`, `reset`, `release`, `pull`, `push`, `prune`, `check`, `fix`, `run`.
- **Variant:** which one, what, or how: `docker:release:pull`, `docker:prune:tags`, `db:seed:demo`.
- Lower case. A segment of several words uses dashes (`docker:generate-base-image`), but one word reads better.
- **File names follow the script name,** with `:` turned into `-`: `db:snapshot` runs `scripts/db-snapshot.sh`,
  `ai:fix:docker` runs `scripts/ai-fix-docker.mjs`. Python files use `_`, so they stay importable: `db_snapshot.py`.
- Avoid implicit `pre`/`post` hooks (`prerelease`); Yarn 2+ doesn't run them. Chain steps explicitly or inside the
  script.

## Paths

File paths given as arguments are relative to the current folder, never to the script's folder. Through yarn or npm,
the current folder is the project root, so `yarn db:import backups/db.sql` reads `<project>/backups/db.sql`.

- **Resolve arguments from the current folder.** Use the path as given, or `path.resolve(arg)` in Node, `realpath` in
  bash, `Path(arg).resolve()` in Python. Never `path.join(__dirname, arg)` or `$(dirname "$0")/$arg`.
- **The same holds for outputs:** `--out reports/x.json` writes to `<project>/reports/x.json`, and a default output is
  shown in `--help` relative to the same folder.
- **Files that belong to the script** (templates, its own helpers, fixtures it ships with) are found from the script's
  location: `CLI_SCRIPT_DIR` in bash, `run.scriptDir` in Node, `cli.SCRIPT_DIR` in Python.

## Three kinds of command

| Kind | Examples | Behaviour |
|---|---|---|
| Read-only | status, list, report, check | Runs directly, nothing to approve |
| Changing | generate, migrate, release, prune | Prints a plan, then asks `Apply? [y/N]` |
| Destructive | restore, reset, drop, wipe | Prints a plan, then wants the word `yes` typed |

## Plan, then approve

A changing command first works out everything it would do and prints it. If you like the plan, you answer `y` and it
applies that same plan. You never run the command twice.

```text
$ yarn logs:prune logs
Delete 3 file(s) older than 7 days in logs:
  - delete logs/a.log (2048 bytes)
  - delete logs/b.tmp (512 bytes)
  - delete logs/c.txt (100 bytes)
Apply? [y/N] y
Deleted 3 file(s) in 0s.

$ yarn logs:prune logs --dry-run     # plan only, never asks
$ yarn logs:prune logs --yes         # applies without asking: CI, scheduled jobs, agents after a preview
```

- **No terminal, no prompt.** When nobody can answer (CI, a pipe, an agent's shell), the command prints the plan and
  stops with exit code 3: "not applied, re-run with `--yes`". A forgotten `--yes` fails loudly instead of hanging or
  silently doing nothing, and an agent can never apply a change by accident.
- **Safety checks come before the plan.** A command refuses things that are almost always mistakes (a folder outside
  the project, a prod target without `--env prod`) before planning. `--force` overrides such a check; it does not skip
  the plan or the question.
- **Nothing to do is success.** An empty plan prints "Nothing to do." and exits 0, which makes commands safe to rerun.
- **Generators offer `--check`.** It exits 1 when the output is out of date and writes nothing, for CI.

## Help

`-h` / `--help` prints the script's header comment, then the options generated from the code, each with its default
and environment variable. The help can't drift from the code, and reading the file top shows the same text.

```text
Delete files older than a number of days. It changes things, so it shows the plan first and asks before applying.

Usage: logs-prune.sh [options] <dir>

Examples:
  logs-prune.sh logs --dry-run                  # plan only
  logs-prune.sh logs -d 30 --pattern '*.log' --pattern '*.tmp'

Options:
  -d, --days <value>           Delete files older than this many days. Default: 7. Env: DAYS.
  -p, --pattern <a,b>          File name patterns to include, repeatable or comma-separated. Default: *.
  -n, --dry-run                Print the plan and exit without changing anything.
  -y, --yes                    Apply without asking (CI, scripts, agents).
```

The header has: one line on what it does (and whether it changes things), a `Usage:` line, and `Examples:` with a
comment on each. Write the examples people will actually copy.

## Options

```text
--name value     --name=value     -n value     -n=value     -nvalue
--flag           --no-flag        -ny (grouped short flags)
--list a,b       --list a --list b
--               everything after it is a positional argument
```

- Quoting is the shell's job: `--title='My docs'` reaches the script as `--title=My docs`. Nothing to implement.
- Positional arguments are for the main object only (a folder, a project, a file); everything else is an option.
- Every environment setting also gets a flag, and the flag wins: `KEEP=3` keeps working for CI, `--keep 3` is what
  people type and what `--help` shows.
- An unknown option is an error (exit 2) with a hint to try `--help`, never silently ignored.

## Common names

| Option | Short | Meaning |
|---|---|---|
| `--help` | `-h` | Show help and examples |
| `--dry-run` | `-n` | Print the plan only |
| `--yes` | `-y` | Apply without asking |
| `--force` | `-f` | Override a safety check |
| `--verbose` | `-v` | More detail, on stderr |
| `--quiet` | `-q` | Errors only |
| `--json` | | Machine-readable output, for read-only commands |
| `--env` | `-e` | `dev`, `ci` or `prod` |
| `--target` | `-t` | A server or deployment target |
| `--all` | | Select everything; required when there is no other selection |
| `--keep` | | How many items to keep when pruning |
| `--out` | `-o` | Output file or folder |
| `--check` | | Generators: fail when the output is out of date |

Before inventing a new name, check this table and the project's other scripts.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Done, or nothing to do |
| 1 | Failed |
| 2 | Usage error: unknown option, missing or bad value |
| 3 | Not applied: there was no terminal to ask, re-run with `--yes` |
| 130 | Declined at the prompt, or interrupted |

## Output

- The plan and results go to stdout; progress, warnings and errors go to stderr. `--json` output is stdout only.
- A changing command ends with one summary line and the elapsed time: `Deleted 3 file(s) in 0s.`
- Plain text, no colours required; if you add colour, respect `NO_COLOR`.

## Which language

- **Bash** for thin wrappers around docker, compose and other CLIs. Start with `set -euo pipefail`.
- **Node, built-ins only,** for anything with logic: parsing files, JSON, HTTP, loops over many items.
- **Python** with `argparse` in Python projects.
- Keep scripts OS-neutral where it is cheap: `find -print0` instead of GNU-only flags, `node:path` instead of string
  paths. Document what is OS-specific instead of hiding it.

## Shared helpers

Each language has one small helper that implements this page, so a script only declares its options and its plan:
[bash/lib/cli.sh](examples/bash/lib/cli.sh), [node/lib/cli.mjs](examples/node/lib/cli.mjs),
[python/cli.py](examples/python/cli.py). Copy the helper into `scripts/lib/` unchanged. A script whose needs the
helper does not cover can use its parts (the Node helper exports the parser, help and prompt separately) or do that
part its own way, as long as the behaviour above stays the same.

## Scripts copied into many projects

Release, prune and e2e scripts exist in most projects. Copies that are edited per project drift apart, and a fix in
one never reaches the others. Keep such scripts identical everywhere, with the project's own values (names, ports,
image tags) in one config file or in `package.json`, and copy them again when they change. Once a script family is
stable, it can become a public `@overdoser` package.
