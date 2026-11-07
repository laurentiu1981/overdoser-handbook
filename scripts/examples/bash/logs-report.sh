#!/usr/bin/env bash
# List files older than a number of days. Read-only: it runs directly, there is nothing to approve.
#
# Usage: logs-report.sh [options] [dir]
#
# Examples:
#   logs-report.sh                       # current folder, files older than 7 days
#   logs-report.sh logs --days 30
#   logs-report.sh logs -d=30 --json     # one JSON object per line, for other tools
#   DAYS=14 logs-report.sh logs          # the env var replaces the default; a flag still wins
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/cli.sh"

cli_init read
cli_option days d value 7 "Only files older than this many days." DAYS
cli_option json - flag 0 "Print JSON lines instead of a table."
cli_parse "$@"
cli_args 0 1 "[dir]"

dir=${ARGS[0]:-.}
[[ $OPT_days =~ ^[0-9]+$ ]] || cli_usage "--days must be a whole number, got '$OPT_days'"
[[ -d $dir ]] || cli_die "not a folder: $dir"

count=0
while IFS= read -r -d '' file; do
  bytes=$(wc -c <"$file" | tr -d ' ')
  if ((OPT_json)); then
    escaped=${file//\\/\\\\}
    printf '{"path":"%s","bytes":%s}\n' "${escaped//\"/\\\"}" "$bytes"
  else
    printf '%10s  %s\n' "$bytes" "$file"
  fi
  count=$((count + 1))
done < <(find "$dir" -type f -mtime +"$OPT_days" -print0 | sort -z)
((OPT_json)) || cli_info "$count file(s) older than $OPT_days days in $dir."
