#!/usr/bin/env bash
# Delete files older than a number of days. It changes things, so it shows the plan first and asks before applying.
#
# Usage: logs-prune.sh [options] <dir>
#
# Examples:
#   logs-prune.sh logs                            # show the plan, then ask "Apply? [y/N]"
#   logs-prune.sh logs --dry-run                  # plan only
#   logs-prune.sh logs --yes                      # apply without asking (CI, agents)
#   logs-prune.sh logs -d 30 --pattern '*.log' --pattern '*.tmp'
#   logs-prune.sh logs --pattern='*.log,*.tmp' -ny    # grouped short flags: dry run
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/cli.sh"

cli_init change
cli_option days d value 7 "Delete files older than this many days." DAYS
cli_option pattern p list '*' "File name patterns to include, repeatable or comma-separated."
cli_parse "$@"
cli_args 1 1 "<dir>"

dir=${ARGS[0]}
[[ $OPT_days =~ ^[0-9]+$ ]] || cli_usage "--days must be a whole number, got '$OPT_days'"
[[ -d $dir ]] || cli_die "not a folder: $dir"

# Build "( -name a -o -name b )" from the pattern list.
cli_list_into patterns "$OPT_pattern"
names=()
for p in "${patterns[@]}"; do names+=(${names:+-o} -name "$p"); done

files=()
while IFS= read -r -d '' file; do
  files+=("$file")
  cli_plan "delete $file ($(wc -c <"$file" | tr -d ' ') bytes)"
done < <(find "$dir" -type f \( "${names[@]}" \) -mtime +"$OPT_days" -print0 | sort -z)

cli_apply "Delete ${#files[@]} file(s) older than $OPT_days days in $dir"
for file in "${files[@]}"; do
  cli_debug "rm $file"
  rm -f -- "$file"
done
cli_done "Deleted ${#files[@]} file(s)"
