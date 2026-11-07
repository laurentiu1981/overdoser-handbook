#!/usr/bin/env bash
# Check that the script examples behave as the standard says: option forms, help, exit codes, plan and approve.
#
# Usage: test.sh
#
# Examples:
#   yarn test                            # or: npm test, or bash scripts/examples/test.sh
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)

# The examples use the published helpers: sync them from @overdoser/scripts into each example folder.
SYNC=$ROOT/node_modules/.bin/overdoser-scripts
[[ -x $SYNC ]] || { echo "test.sh: @overdoser/scripts is not installed; run yarn install (or npm install) first" >&2; exit 1; }
for lang in bash node python; do (cd "$HERE" && "$SYNC" sync "$lang/lib" --lang "$lang" --yes --quiet); done
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
pass=0 fail=0

ok() { pass=$((pass + 1)); }
bad() { # bad <message>: record a failure and show the last output
  fail=$((fail + 1))
  echo "FAIL $1"
  sed 's/^/  | /' "$WORK/out"
}
check() { # check <name> <expected exit> <command...>
  local name=$1 want=$2 got=0
  shift 2
  "$@" >"$WORK/out" 2>&1 </dev/null || got=$?
  if [[ $got == "$want" ]]; then ok; else bad "$name: exit $got, want $want"; fi
}
has() { # has <name> <text>: the last output contains the text
  if grep -qF -- "$2" "$WORK/out"; then ok; else bad "$1: output lacks '$2'"; fi
}
fixture() {
  rm -rf "$WORK/logs" && mkdir -p "$WORK/logs"
  touch -t 202001010000 "$WORK/logs/a.log" "$WORK/logs/b.tmp" "$WORK/logs/c.txt"
  touch "$WORK/logs/new.log"
}
cd "$WORK"

for impl in "bash $HERE/bash/logs-prune.sh" "python3 $HERE/python/logs_prune.py"; do
  read -r -a run <<<"$impl"
  tag=${run[1]##*/}
  fixture
  check "$tag help" 0 "${run[@]}" --help
  has "$tag help" "Examples:"
  for form in "--days 30" "--days=30" "-d 30" "-d=30" "-d30"; do
    read -r -a f <<<"$form"
    check "$tag $form" 0 "${run[@]}" logs "${f[@]}" --dry-run
    has "$tag $form" "delete logs/a.log"
  done
  check "$tag no terminal" 3 "${run[@]}" logs
  has "$tag no terminal" "Re-run with --yes"
  check "$tag unknown option" 2 "${run[@]}" logs --bogus
  check "$tag missing value" 2 "${run[@]}" logs --days
  check "$tag list repeat" 0 "${run[@]}" logs --pattern '*.log' --pattern '*.tmp' -n
  has "$tag list repeat" "Delete 2 file(s)"
  check "$tag list comma" 0 "${run[@]}" logs --pattern='*.log,*.tmp' -n
  has "$tag list comma" "Delete 2 file(s)"
  check "$tag env default" 0 env DAYS=100000 "${run[@]}" logs -n
  has "$tag env default" "Nothing to do."
  check "$tag flag beats env" 0 env DAYS=100000 "${run[@]}" logs --days 1 -n
  has "$tag flag beats env" "Delete 3 file(s)"
  check "$tag apply" 0 "${run[@]}" logs --yes
  if [[ -f logs/new.log && ! -f logs/a.log ]]; then ok; else bad "$tag apply: wrong files left"; fi
  check "$tag nothing to do" 0 "${run[@]}" logs --yes
  has "$tag nothing to do" "Nothing to do."
done

fixture
check "bash grouped -ny" 0 bash "$HERE/bash/logs-prune.sh" logs -ny
has "bash grouped -ny" "Dry run: nothing changed."
check "bash too many args" 2 bash "$HERE/bash/logs-prune.sh" logs extra
check "bash no-flag" 0 bash "$HERE/bash/logs-report.sh" logs --json --no-json
has "bash no-flag" "file(s) older than 7 days"
check "bash read-only json" 0 bash "$HERE/bash/logs-report.sh" logs --json
has "bash read-only json" '{"path":"logs/a.log","bytes":0}'
check "bash read-only has no --yes" 2 bash "$HERE/bash/logs-report.sh" logs --yes

mkdir -p data && touch data/x data/y && echo '{}' >seed.json
check "destructive no terminal" 3 bash "$HERE/bash/data-reset.sh" data
check "destructive outside" 1 bash "$HERE/bash/data-reset.sh" /tmp --yes
has "destructive outside" "add --force"
check "destructive apply" 0 bash "$HERE/bash/data-reset.sh" data --seed seed.json --yes
if [[ $(ls data) == seed.json ]]; then ok; else bad "destructive apply: data is $(ls data)"; fi

mkdir -p docs && printf '# Alpha\n' >docs/a.md && printf '# Beta\n' >docs/b.md
gen="$HERE/node/docs-generate-index.mjs"
check "node help" 0 node "$gen" --help
has "node help" "Default: <dir>/INDEX.md. Env: INDEX_OUT."
check "node check stale" 1 node "$gen" docs --check
check "node no terminal" 3 node "$gen" docs
for form in "-t Docs" "-t=Docs" "-tDocs" "--title=Docs" "--title Docs"; do
  read -r -a f <<<"$form"
  check "node $form" 0 node "$gen" docs "${f[@]}" -n
  has "node $form" "create docs/INDEX.md (2 entries)"
done
check "node apply" 0 node "$gen" docs -y
check "node idempotent" 0 node "$gen" docs -y
has "node idempotent" "Nothing to do."
check "node check fresh" 0 node "$gen" docs --check
check "node unknown" 2 node "$gen" docs -z

# Through a package manager: file arguments resolve from the current folder (the project root), not from the folder
# the scripts live in.
if command -v yarn >/dev/null 2>&1; then
  mkdir -p proj/backups/logs proj/docs
  printf '{"name":"demo","private":true,"scripts":{"logs:prune":"bash %s","logs:prune:py":"python3 %s",%s}}\n' \
    "$HERE/bash/logs-prune.sh" "$HERE/python/logs_prune.py" \
    "\"docs:generate:index\":\"node $HERE/node/docs-generate-index.mjs\"" >proj/package.json
  touch -t 202001010000 proj/backups/logs/old.log
  printf '# A\n' >proj/docs/a.md
  cd proj
  for s in logs:prune logs:prune:py; do
    check "yarn $s with a project path" 0 yarn -s "$s" backups/logs -n
    has "yarn $s with a project path" "delete backups/logs/old.log"
  done
  check "yarn output relative to the project" 0 yarn -s docs:generate:index docs --out reports/index.md -y
  if [[ -f reports/index.md ]]; then ok; else bad "yarn output relative to the project: reports/index.md missing"; fi
  cd "$WORK"
else
  echo "skip: yarn not installed, package-manager tests not run"
fi

# A real terminal: util-linux `script` gives the command a pty, so the prompt path runs.
if script -qec true /dev/null >/dev/null 2>&1; then
  fixture
  printf 'n\n' | script -qec "bash $HERE/bash/logs-prune.sh logs" /dev/null >"$WORK/out" 2>&1 || true
  has "prompt declined" "Not applied."
  if [[ -f logs/a.log ]]; then ok; else bad "prompt declined: file deleted"; fi
  printf 'y\n' | script -qec "bash $HERE/bash/logs-prune.sh logs" /dev/null >"$WORK/out" 2>&1 || true
  has "prompt approved" "Deleted 3 file(s)"
  mkdir -p data && touch data/z
  printf 'y\n' | script -qec "bash $HERE/bash/data-reset.sh data" /dev/null >"$WORK/out" 2>&1 || true
  has "destructive wants the word yes" "Not applied."
else
  echo "skip: no util-linux script command, prompt paths not tested"
fi

echo "$pass passed, $fail failed"
((fail == 0))
