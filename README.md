# Overdoser handbook

How code, scripts, docs, helper tools and AI agents work across my projects. It is a reference for people and for
agents: conventions with their reasons, not hard rules. Where a project does something differently on purpose, its own
`CLAUDE.md` or docs say so, and that wins.

Sections are added one at a time.

| Section | What it covers |
|---|---|
| [Scripts and CLIs](scripts/README.md) | One standard for project scripts, with tested examples in bash, Node and Python |
| [Rules for projects](rules/README.md) | Short files that projects copy into `.claude/rules/` |

## How projects use it

- Agents only read what is in the repo they work in, so the short forms in [rules/](rules/README.md) are copied into
  each project's `.claude/rules/` unchanged. Change the handbook, then copy again; never edit a project's copy.
- Shared code lives in public `@overdoser` npm packages and is copied into projects unchanged, such as the CLI
  helpers from [@overdoser/scripts](https://www.npmjs.com/package/@overdoser/scripts). The examples here use them.

## Changing the handbook

- Write conventions with a reason, so a reader can judge an exception.
- Keep `rules/` short: every line of a rule file is loaded into agent sessions.
- Examples must run: `yarn test` checks the script examples.
- Name no projects or clients here.
