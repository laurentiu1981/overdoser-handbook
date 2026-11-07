# Script examples

Working examples of the [scripts standard](../README.md), one helper per language plus a script of each kind.
`yarn test` (or `bash scripts/examples/test.sh`) checks all of them: option forms, help, exit codes, plan and approve,
including the prompt on a real terminal.

| File | Kind | Shows |
|---|---|---|
| [bash/lib/cli.sh](bash/lib/cli.sh) | helper | Options, `--help` from the header, plan and approve |
| [bash/logs-report.sh](bash/logs-report.sh) | read-only | Runs directly, `--json`, env default |
| [bash/logs-prune.sh](bash/logs-prune.sh) | changing | Plan, `Apply? [y/N]`, list option, `--dry-run`, `--yes` |
| [bash/data-reset.sh](bash/data-reset.sh) | destructive | Typed `yes`, a safety check with `--force` |
| [node/lib/cli.mjs](node/lib/cli.mjs) | helper | Same behaviour; also exports the parser, help and prompt |
| [node/docs-generate-index.mjs](node/docs-generate-index.mjs) | changing | Writes only when content changes, `--check` for CI |
| [python/cli.py](python/cli.py) | helper | Standard options and plan on top of `argparse` |
| [python/logs_prune.py](python/logs_prune.py) | changing | The bash prune example in Python |

## Using them in a project

1. Copy the helper into `scripts/lib/` (Python: next to the scripts) without changes.
2. Start the script from the example of the same kind: header comment first, then the options, then the plan.
3. Add a `package.json` script, so people and agents find it:

```json
{
  "scripts": {
    "logs:report": "bash scripts/logs-report.sh",
    "logs:prune": "bash scripts/logs-prune.sh",
    "data:reset": "bash scripts/data-reset.sh",
    "docs:generate:index": "node scripts/docs-generate-index.mjs"
  }
}
```

Arguments pass through, and file paths are relative to the project root: `yarn logs:prune logs --days 30 --yes`.
Each file is named after its script, so `logs:prune` runs `scripts/logs-prune.sh`.

## Try them

```bash
mkdir -p /tmp/demo/logs && touch -t 202001010000 /tmp/demo/logs/old.log && cd /tmp/demo
bash ~/GITCRK/overdoser-handbook/scripts/examples/bash/logs-prune.sh --help
bash ~/GITCRK/overdoser-handbook/scripts/examples/bash/logs-prune.sh logs          # plan, then the question
bash ~/GITCRK/overdoser-handbook/scripts/examples/bash/logs-prune.sh logs -n       # plan only
```
