#!/usr/bin/env node
// Generate an index file listing the Markdown files in a folder with their first heading.
// It writes a file, so it shows the plan and asks first; it only writes when the content would change.
//
// Usage: docs-generate-index.mjs [options] [dir]
//
// Examples:
//   docs-generate-index.mjs docs                     # plan, then "Apply? [y/N]"
//   docs-generate-index.mjs docs --dry-run           # plan only
//   docs-generate-index.mjs docs --yes               # write without asking
//   docs-generate-index.mjs docs --check             # CI: exit 1 when the index is out of date, write nothing
//   docs-generate-index.mjs docs -o=docs/README.md --title 'Docs index'
//   docs-generate-index.mjs docs --out index.md     # paths are relative to the current folder, outputs too
import fs from 'node:fs';
import path from 'node:path';
import { cli } from './lib/cli.mjs';

const run = cli({
  kind: 'change',
  args: { min: 0, max: 1, usage: '[dir]' },
  options: {
    out: { short: 'o', type: 'value', env: 'INDEX_OUT', help: 'File to write. Default: <dir>/INDEX.md.' },
    title: { short: 't', type: 'value', default: 'Index', help: 'Heading of the generated file.' },
    check: { type: 'flag', help: 'Only check that the file is up to date: exit 0 if it is, 1 if not.' },
  },
});

const dir = run.args[0] || '.';
if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) run.fail(`not a folder: ${dir}`);
const outFile = run.opts.out || path.join(dir, 'INDEX.md');

const entries = fs.readdirSync(dir)
  .filter((f) => f.endsWith('.md') && path.resolve(dir, f) !== path.resolve(outFile))
  .sort()
  .map((f) => {
    const heading = fs.readFileSync(path.join(dir, f), 'utf8').match(/^#\s+(.+)$/m)?.[1] ?? f;
    return `- [${heading}](${f})`;
  });
const content = `# ${run.opts.title}\n\n${entries.join('\n')}\n`;
const current = fs.existsSync(outFile) ? fs.readFileSync(outFile, 'utf8') : null;

if (run.opts.check) {
  if (current === content) { run.info(`${outFile} is up to date.`); process.exit(0); }
  run.fail(`${outFile} is out of date; run without --check to update it.`);
}
if (current !== content) run.plan(`${current === null ? 'create' : 'update'} ${outFile} (${entries.length} entries)`);

await run.apply('Update the index');
fs.mkdirSync(path.dirname(outFile), { recursive: true });
fs.writeFileSync(outFile, content);
run.done(`Wrote ${outFile}`);
