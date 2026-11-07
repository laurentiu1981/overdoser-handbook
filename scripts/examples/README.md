# Script examples

Working examples of the [scripts standard](../README.md), a script of each kind in bash, Node and Python. Their
helpers come from [@overdoser/scripts](https://www.npmjs.com/package/@overdoser/scripts), the way a project gets them.
`yarn test` (or `npm test`) syncs the helpers into each `lib/` folder and checks every example: option forms, help,
exit codes, plan and approve, including the prompt on a real terminal. Run `yarn install` first.

| File | Kind | Shows |
|---|---|---|
| [bash/logs-report.sh](bash/logs-report.sh) | read-only | Runs directly, `--json`, env default |
| [bash/logs-prune.sh](bash/logs-prune.sh) | changing | Plan, `Apply? [y/N]`, list option, `--dry-run`, `--yes` |
| [bash/data-reset.sh](bash/data-reset.sh) | destructive | Typed `yes`, a safety check with `--force` |
| [node/docs-generate-index.mjs](node/docs-generate-index.mjs) | changing | Writes only when content changes, `--check` for CI |
| [python/logs_prune.py](python/logs_prune.py) | changing | The bash prune example in Python |

## Using them in a project

1. Copy the helpers into `scripts/lib/`: `npx @overdoser/scripts sync --lang bash,node,python` (only the languages
   the project uses).
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

Run `yarn test` once first: it puts the helpers in place.

```bash
mkdir -p /tmp/demo/logs && touch -t 202001010000 /tmp/demo/logs/old.log && cd /tmp/demo
bash ~/GITCRK/overdoser-handbook/scripts/examples/bash/logs-prune.sh --help
bash ~/GITCRK/overdoser-handbook/scripts/examples/bash/logs-prune.sh logs          # plan, then the question
bash ~/GITCRK/overdoser-handbook/scripts/examples/bash/logs-prune.sh logs -n       # plan only
```
