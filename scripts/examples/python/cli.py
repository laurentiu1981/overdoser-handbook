"""cli.py: the standard options and plan-then-approve on top of argparse. Python 3.9+, standard library only.

Copy this file next to your scripts and use it:

    \"\"\"Delete files older than a number of days.

    Examples:
      logs_prune.py logs --dry-run
    \"\"\"
    import cli
    parser = cli.parser(__doc__, kind="change")
    parser.add_argument("dir")
    parser.add_argument("-d", "--days", type=int, default=cli.env("DAYS", 7),
                        help="Older than this. Default: %(default)s.")
    args = parser.parse_args(cli.normalize())
    plan = cli.Plan(args, kind="change")
    plan.add("delete logs/a.log")
    plan.apply("Delete 1 file")        # prints the plan; returns only once approved
    ...
    plan.done()

Paths: file arguments are relative to the current folder, which is the project root when run through yarn or npm.
Never resolve them from the script's folder; SCRIPT_DIR is only for files that belong to the script.

argparse already accepts --name value, --name=value, -n value and -nvalue, and exits with 2 on a usage error.
normalize() adds -n=value. Exit codes: 0 done, 1 failure, 2 usage error, 3 not applied (no terminal), 130 declined.
"""
import argparse
import os
import re
import sys
import time

KINDS = ("read", "change", "destructive")
SCRIPT_DIR = os.path.dirname(os.path.realpath(sys.argv[0]))


def normalize(argv=None):
    """Turn -k=value into -k value, which argparse does not accept on its own."""
    argv = sys.argv[1:] if argv is None else list(argv)
    out = []
    for i, a in enumerate(argv):
        if a == "--":
            out.extend(argv[i:])
            break
        m = re.match(r"^-([A-Za-z])=(.*)$", a)
        out.extend(["-" + m.group(1), m.group(2)] if m else [a])
    return out


def env(name, default):
    """An environment variable replaces the default; a flag on the command line still wins."""
    value = os.environ.get(name)
    return type(default)(value) if value not in (None, "") and default is not None else (value or default)


def parser(doc, kind="read"):
    """An ArgumentParser whose help is the module docstring, with the standard options for the kind."""
    if kind not in KINDS:
        raise ValueError(f"kind must be one of {KINDS}, not {kind!r}")
    summary, _, rest = (doc or "").strip().partition("\n\n")
    p = argparse.ArgumentParser(
        description=summary, epilog=rest or None, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    if kind != "read":
        p.add_argument("-n", "--dry-run", action="store_true",
                       help="Print the plan and exit without changing anything.")
        p.add_argument("-y", "--yes", action="store_true", help="Apply without asking (CI, scripts, agents).")
    p.add_argument("-v", "--verbose", action="store_true", help="Print more detail.")
    p.add_argument("-q", "--quiet", action="store_true", help="Print errors only.")
    return p


class Plan:
    """Collect the planned changes, print them, and ask before applying."""

    def __init__(self, args, kind="change", name=None):
        self.args, self.kind, self.lines = args, kind, []
        self.name = name or os.path.basename(sys.argv[0])
        self.started = time.monotonic()

    def add(self, line):
        self.lines.append(line)

    def info(self, msg):
        if not self.args.quiet:
            print(msg)

    def apply(self, title="Plan"):
        if not self.lines:
            self.info("Nothing to do.")
            sys.exit(0)
        if not (self.args.yes and self.args.quiet):
            print(f"{title}:")
            print("\n".join(f"  - {line}" for line in self.lines))
        if self.args.dry_run:
            self.info("Dry run: nothing changed.")
            sys.exit(0)
        if not self.args.yes:
            sys.stdout.flush()
            if not sys.stdin.isatty():
                print(f"{self.name}: not applied, there is no terminal to ask. "
                      "Re-run with --yes to apply, or --dry-run to preview.", file=sys.stderr)
                sys.exit(3)
            try:
                if self.kind == "destructive":
                    ok = input("This cannot be undone. Type yes to apply: ").strip() == "yes"
                else:
                    ok = input("Apply? [y/N] ").strip().lower() in ("y", "yes")
            except EOFError:
                ok = False
            if not ok:
                print("Not applied.", file=sys.stderr)
                sys.exit(130)
        self.started = time.monotonic()

    def done(self, msg="Done"):
        self.info(f"{msg} in {round(time.monotonic() - self.started)}s.")
