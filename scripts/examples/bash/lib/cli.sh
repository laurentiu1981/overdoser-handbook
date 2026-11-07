# shellcheck shell=bash
# cli.sh: option parsing, --help and plan-then-approve for bash scripts. Bash 4.4+, no dependencies.
#
# Copy this file into a project (scripts/lib/cli.sh) and source it:
#
#   #!/usr/bin/env bash
#   # Delete files older than a number of days.            <- the header comment is the --help text
#   #
#   # Usage: prune-old-files.sh [options] <dir>
#   #
#   # Examples:
#   #   prune-old-files.sh logs            # show the plan, then ask
#   #   prune-old-files.sh logs --yes      # apply without asking
#   set -euo pipefail
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/cli.sh"
#
#   cli_init change                                   # read | change | destructive
#   cli_option days d value 7 "Delete files older than this many days" DAYS
#   cli_parse "$@"                                    # sets OPT_days, OPT_dry_run, OPT_yes, ... and ARGS
#   cli_args 1 1 "<dir>"                              # exactly one positional argument
#   cli_plan "delete logs/a.log"                      # one line per change
#   cli_apply "Delete 1 file"                         # prints the plan; returns only once approved
#   rm -f logs/a.log
#   cli_done
#
# Options: cli_option <name> <short or -> <flag|value|list> <default> <help> [ENV_VAR]
#   - flag: 0 or 1; --name sets 1, --no-name sets 0.
#   - value: one string. list: repeatable and comma-joined (--tag a --tag b == --tag a,b).
#   - ENV_VAR, when set, replaces the default; a flag on the command line always wins.
# Accepted forms: --name value, --name=value, -n value, -n=value, -nvalue, grouped flags (-ny), and -- to end options.
#
# Kinds: read runs directly. change and destructive get -n/--dry-run and -y/--yes; cli_apply prints the plan, then
# asks "Apply? [y/N]" (change) or wants the word "yes" typed (destructive). Without a terminal it never asks: it stops
# with exit code 3 and says to re-run with --yes. Exit codes: 0 done, 1 failure, 2 usage error, 3 not applied
# (no terminal), 130 declined.

CLI_NAME=${CLI_NAME:-$(basename "$0")}
ARGS=()
PLAN=()
_CLI_KIND=read
_CLI_NAMES=()
_CLI_SHORTS=()
_CLI_TYPES=()
_CLI_DEFAULTS=()
_CLI_HELPS=()
_CLI_ENVS=()
_CLI_SEEN=' '
_CLI_I=0
_CLI_START=$SECONDS

cli_init() {
  _CLI_KIND=${1:-read}
  case $_CLI_KIND in
    read | change | destructive) ;;
    *) _cli_bug "cli_init: kind must be read, change or destructive, not '$_CLI_KIND'" ;;
  esac
}

cli_option() {
  local name=$1 short=${2:--} type=$3 default=${4-} help=${5-} env=${6-} value
  [[ $short == - ]] && short=
  case $type in flag | value | list) ;; *) _cli_bug "cli_option $name: type must be flag, value or list" ;; esac
  _CLI_NAMES+=("$name") _CLI_SHORTS+=("$short") _CLI_TYPES+=("$type")
  _CLI_DEFAULTS+=("$default") _CLI_HELPS+=("$help") _CLI_ENVS+=("$env")
  value=$default
  if [[ -n $env && -n ${!env-} ]]; then value=${!env}; fi
  if [[ $type == flag ]]; then _cli_bool "$name" "${value:-0}"; else _cli_set "$name" "$value"; fi
}

cli_parse() {
  _cli_add_standard
  local a name val has type var
  # --help wins over everything else on the line, so it works even next to a mistake.
  for a in "$@"; do
    [[ $a == -- ]] && break
    if [[ $a == -h || $a == --help ]]; then cli_help; exit 0; fi
  done
  while (($#)); do
    a=$1 has=0 val=
    shift
    case $a in
      --) ARGS+=("$@"); break ;;
      --*=*) name=${a%%=*} name=${name#--} val=${a#*=} has=1 ;;
      --?*) name=${a#--} ;;
      -[!-]=*)
        _cli_find short "${a:1:1}" || cli_usage "unknown option ${a%%=*}"
        name=${_CLI_NAMES[_CLI_I]} val=${a:3} has=1
        ;;
      -[!-])
        _cli_find short "${a:1:1}" || cli_usage "unknown option $a"
        name=${_CLI_NAMES[_CLI_I]}
        ;;
      -[!-]?*)
        _cli_find short "${a:1:1}" || cli_usage "unknown option -${a:1:1}"
        name=${_CLI_NAMES[_CLI_I]}
        if [[ ${_CLI_TYPES[_CLI_I]} == flag ]]; then set -- "-${a:2}" "$@"; else val=${a:2} has=1; fi
        ;;
      *) ARGS+=("$a"); continue ;;
    esac
    if ! _cli_find long "$name"; then
      if [[ $name == no-* ]] && ((!has)) && _cli_find long "${name#no-}" && [[ ${_CLI_TYPES[_CLI_I]} == flag ]]; then
        _cli_set "${name#no-}" 0
        continue
      fi
      cli_usage "unknown option --$name"
    fi
    type=${_CLI_TYPES[_CLI_I]}
    if [[ $type == flag ]]; then
      if ((has)); then _cli_bool "$name" "$val"; else _cli_set "$name" 1; fi
      continue
    fi
    if ((!has)); then
      (($#)) || cli_usage "option --$name needs a value"
      val=$1
      shift
    fi
    if [[ $type == list && $_CLI_SEEN == *" $name "* ]]; then
      var=$(_cli_var "$name")
      printf -v "$var" '%s,%s' "${!var}" "$val"
    else
      _cli_set "$name" "$val"
    fi
    _CLI_SEEN+="$name "
  done
}

# cli_args <min> <max or -> <usage>: check the number of positional arguments.
cli_args() {
  local min=$1 max=$2 n=${#ARGS[@]}
  ((n >= min)) || cli_usage "missing argument: ${3:-}"
  [[ $max == - ]] || ((n <= max)) || cli_usage "too many arguments: ${ARGS[*]:max}"
}

# cli_list_into <array name> <comma-joined value>: split a list option into an array.
cli_list_into() {
  # shellcheck disable=SC2034
  IFS=, read -r -a "$1" <<<"$2"
}

cli_plan() { PLAN+=("$*"); }

cli_apply() {
  local title=${1:-Plan} answer
  [[ $_CLI_KIND != read ]] || _cli_bug "cli_apply needs cli_init change or destructive"
  if ((${#PLAN[@]} == 0)); then
    cli_info "Nothing to do."
    exit 0
  fi
  if ! ((OPT_yes && OPT_quiet)); then
    printf '%s:\n' "$title"
    printf '  - %s\n' "${PLAN[@]}"
  fi
  if ((OPT_dry_run)); then
    cli_info "Dry run: nothing changed."
    exit 0
  fi
  if ((!OPT_yes)); then
    if [[ ! -t 0 ]]; then
      printf '%s: not applied, there is no terminal to ask. Re-run with --yes to apply, or --dry-run to preview.\n' \
        "$CLI_NAME" >&2
      exit 3
    fi
    if [[ $_CLI_KIND == destructive ]]; then
      read -r -p "This cannot be undone. Type yes to apply: " answer || true
      [[ $answer == yes ]] || { echo "Not applied." >&2; exit 130; }
    else
      read -r -p "Apply? [y/N] " answer || true
      [[ $answer == [yY] || $answer == [yY][eE][sS] ]] || { echo "Not applied." >&2; exit 130; }
    fi
  fi
  _CLI_START=$SECONDS
}

cli_done() { cli_info "${1:-Done} in $((SECONDS - _CLI_START))s."; }

cli_info() { ((OPT_quiet)) || printf '%s\n' "$*"; }
cli_debug() { if ((OPT_verbose)); then printf '%s\n' "$*" >&2; fi; }
cli_warn() { printf '%s: %s\n' "$CLI_NAME" "$*" >&2; }
cli_die() {
  printf '%s: %s\n' "$CLI_NAME" "$1" >&2
  exit "${2:-1}"
}
cli_usage() {
  printf '%s: %s\nTry --help.\n' "$CLI_NAME" "$1" >&2
  exit 2
}

cli_help() {
  local i left right type
  awk 'NR == 1 && /^#!/ { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
  printf '\nOptions:\n'
  for i in "${!_CLI_NAMES[@]}"; do
    type=${_CLI_TYPES[i]}
    left="--${_CLI_NAMES[i]}"
    [[ $type == value ]] && left+=" <value>"
    [[ $type == list ]] && left+=" <a,b>"
    if [[ -n ${_CLI_SHORTS[i]} ]]; then left="-${_CLI_SHORTS[i]}, $left"; else left="    $left"; fi
    right=${_CLI_HELPS[i]}
    if [[ $type == flag ]]; then
      [[ ${_CLI_DEFAULTS[i]} == 1 ]] && right+=" Default: on (--no-${_CLI_NAMES[i]} turns it off)."
    elif [[ -n ${_CLI_DEFAULTS[i]} ]]; then
      right+=" Default: ${_CLI_DEFAULTS[i]}."
    fi
    [[ -n ${_CLI_ENVS[i]} ]] && right+=" Env: ${_CLI_ENVS[i]}."
    printf '  %-28s %s\n' "$left" "$right"
  done
}

_cli_add_standard() {
  _cli_find long help || cli_option help h flag 0 "Show this help and exit."
  if [[ $_CLI_KIND != read ]]; then
    _cli_find long dry-run || cli_option dry-run n flag 0 "Print the plan and exit without changing anything."
    _cli_find long yes || cli_option yes y flag 0 "Apply without asking (CI, scripts, agents)."
  else
    OPT_dry_run=0 OPT_yes=0
  fi
  _cli_find long verbose || cli_option verbose v flag 0 "Print more detail."
  _cli_find long quiet || cli_option quiet q flag 0 "Print errors only."
}

_cli_find() {
  local i
  for i in "${!_CLI_NAMES[@]}"; do
    if [[ $1 == long && ${_CLI_NAMES[i]} == "$2" ]] || [[ $1 == short && -n $2 && ${_CLI_SHORTS[i]} == "$2" ]]; then
      _CLI_I=$i
      return 0
    fi
  done
  return 1
}

_cli_var() { printf 'OPT_%s' "${1//-/_}"; }
_cli_set() { printf -v "$(_cli_var "$1")" '%s' "$2"; }
_cli_bool() {
  case $2 in
    1 | true | yes | on) _cli_set "$1" 1 ;;
    0 | false | no | off | '') _cli_set "$1" 0 ;;
    *) cli_usage "option --$1 takes no value or one of true/false, got '$2'" ;;
  esac
}
_cli_bug() {
  printf '%s: %s\n' "$CLI_NAME" "$1" >&2
  exit 70
}
