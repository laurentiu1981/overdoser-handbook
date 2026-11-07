# Rules for projects

Short files that projects copy into `.claude/rules/`, unchanged. Claude Code loads every file in that folder; a file
with `paths:` frontmatter only loads when the agent works on matching files.

| File | Loads for | Long form |
|---|---|---|
| [scripts.md](scripts.md) | scripts, shell files, Makefiles, `package.json` | [Scripts and CLIs](../scripts/README.md) |

- Keep the version line at the top of a copy, and never edit it in the project.
- List the copied files in the project's `AGENTS.md`, since Codex and Gemini don't load `.claude/rules/`.
