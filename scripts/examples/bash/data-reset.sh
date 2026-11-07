#!/usr/bin/env bash
# Empty a data folder and optionally put a seed file back. Destructive: it shows the plan, then wants "yes" typed.
#
# Usage: data-reset.sh [options] <dir>
#
# Examples:
#   data-reset.sh data                           # plan, then "Type yes to apply"
#   data-reset.sh data --seed fixtures/seed.json
#   data-reset.sh data --yes                     # no prompt (CI); still refuses folders outside this one
#   data-reset.sh /tmp/scratch --force --yes     # --force overrides that safety check
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/cli.sh"

cli_init destructive
cli_option seed s value '' "File to copy into the folder after emptying it."
cli_option force f flag 0 "Allow a folder outside the current one."
cli_parse "$@"
cli_args 1 1 "<dir>"

dir=${ARGS[0]}
[[ -d $dir ]] || cli_die "not a folder: $dir"
abs=$(cd "$dir" && pwd -P)
here=$(pwd -P)
# Safety checks come before the plan; --force is the documented way past the soft one.
[[ $abs != / && $abs != "$HOME" ]] || cli_die "refusing to empty $abs"
[[ $abs == "$here"/* || $OPT_force == 1 ]] || cli_die "$abs is outside $here; add --force if that is intended"
[[ -z $OPT_seed || -f $OPT_seed ]] || cli_die "seed file not found: $OPT_seed"

entries=$(find "$abs" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
((entries == 0)) || cli_plan "delete everything in $abs ($entries entries)"
[[ -z $OPT_seed ]] || cli_plan "copy $OPT_seed into $abs"

cli_apply "Reset $abs"
find "$abs" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
[[ -z $OPT_seed ]] || cp -- "$OPT_seed" "$abs/"
cli_done "Reset $abs"
