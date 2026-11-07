#!/usr/bin/env python3
"""Delete files older than a number of days. It shows the plan first and asks before applying.

Examples:
  logs_prune.py logs                       # plan, then "Apply? [y/N]"
  logs_prune.py logs --dry-run             # plan only
  logs_prune.py logs -d=30 --yes           # apply without asking
  logs_prune.py logs --pattern '*.log' --pattern '*.tmp'
"""
import fnmatch
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import cli  # noqa: E402

p = cli.parser(__doc__, kind="change")
p.add_argument("dir", help="Folder to prune.")
p.add_argument("-d", "--days", type=int, default=cli.env("DAYS", 7),
               help="Delete files older than this many days. Default: %(default)s. Env: DAYS.")
p.add_argument("-p", "--pattern", action="append", default=None,
               help="File name patterns to include, repeatable or comma-separated. Default: *.")
args = p.parse_args(cli.normalize())
patterns = [x for v in (args.pattern or ["*"]) for x in v.split(",")]

if not os.path.isdir(args.dir):
    print(f"logs_prune.py: not a folder: {args.dir}", file=sys.stderr)
    sys.exit(1)

cutoff = time.time() - args.days * 86400
plan = cli.Plan(args, kind="change")
files = []
for root, _, names in os.walk(args.dir):
    for n in sorted(names):
        f = os.path.join(root, n)
        if any(fnmatch.fnmatch(n, pat) for pat in patterns) and os.path.getmtime(f) < cutoff:
            files.append(f)
            plan.add(f"delete {f} ({os.path.getsize(f)} bytes)")

plan.apply(f"Delete {len(files)} file(s) older than {args.days} days in {args.dir}")
for f in files:
    os.remove(f)
plan.done(f"Deleted {len(files)} file(s)")
