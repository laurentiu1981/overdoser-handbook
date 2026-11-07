# Script examples

Working examples of the [scripts standard](../README.md), one helper per language plus a script of each kind.
`yarn test` (or `bash scripts/examples/test.sh`) checks all of them: option forms, help, exit codes, plan and approve,
including the prompt on a real terminal.

| File | Kind | Shows |
|---|---|---|
| [bash/lib/cli.sh](bash/lib/cli.sh) | helper | Options, `--help` from the header, plan and approve |
| [bash/report-old-files.sh](bash/report-old-files.sh) | read-only | Runs directly, `--json`, env default |
| [bash/prune-old-files.sh](bash/prune-old-files.sh) | changing | Plan, `Apply? [y/N]`, list option, `--dry-run`, `--yes` |
| [bash/reset-data.sh](bash/reset-data.sh) | destructive | Typed `yes`, a safety check with `--force` |
| [node/lib/cli.mjs](node/lib/cli.mjs) | helper | Same behaviour; also exports the parser, help and prompt |
| [node/generate-index.mjs](node/generate-index.mjs) | changing | Writes only when content changes, `--check` for CI |
| [python/cli.py](python/cli.py) | helper | Standard options and plan on top of `argparse` |
| [python/prune_old_files.py](python/prune_old_files.py) | changing | The bash prune example in Python |

## Using them in a project

1. Copy the helper into `scripts/lib/` (Python: next to the scripts) without changes.
2. Start the script from the example of the same kind: header comment first, then the options, then the plan.
3. Add a `package.json` script, so people and agents find it:

```json
{
  "scripts": {
    "logs:report": "bash scripts/report-old-files.sh",
    "logs:prune": "bash scripts/prune-old-files.sh",
    "data:reset": "bash scripts/reset-data.sh",
    "docs:index": "node scripts/generate-index.mjs"
  }
}
```

Arguments pass through: `yarn logs:prune logs --days 30 --yes`.

## Try them

```bash
mkdir -p /tmp/demo/logs && touch -t 202001010000 /tmp/demo/logs/old.log && cd /tmp/demo
bash ~/GITCRK/overdoser-handbook/scripts/examples/bash/prune-old-files.sh --help
bash ~/GITCRK/overdoser-handbook/scripts/examples/bash/prune-old-files.sh logs          # plan, then the question
bash ~/GITCRK/overdoser-handbook/scripts/examples/bash/prune-old-files.sh logs -n       # plan only
```
