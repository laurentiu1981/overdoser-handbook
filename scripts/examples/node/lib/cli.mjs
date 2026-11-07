// cli.mjs: option parsing, --help and plan-then-approve for Node scripts. Node 18+, built-ins only.
//
// Copy this file into a project (scripts/lib/cli.mjs) and use it:
//
//   #!/usr/bin/env node
//   // Generate INDEX.md from the Markdown files in a folder.     <- the header comment is the --help text
//   //
//   // Usage: generate-index.mjs [options] [dir]
//   //
//   // Examples:
//   //   generate-index.mjs docs           # show the plan, then ask
//   import { cli } from './lib/cli.mjs';
//
//   const run = cli({
//     kind: 'change',                                           // 'read' | 'change' | 'destructive'
//     args: { min: 0, max: 1, usage: '[dir]' },
//     options: { out: { short: 'o', type: 'value', default: 'INDEX.md', env: 'OUT', help: 'File to write.' } },
//   });
//   run.opts.out; run.args;                                     // option names in camelCase: dry-run -> dryRun
//   run.plan('write docs/INDEX.md');
//   await run.apply('Update the index');                        // prints the plan; returns only once approved
//   run.done();
//
// Option types: flag (boolean, --no-name turns it off), value (string), list (repeatable or comma-separated; an
// array).
// Accepted forms: --name value, --name=value, -n value, -n=value, -nvalue, grouped flags (-ny), and -- to end options.
// Exit codes: 0 done, 1 failure, 2 usage error, 3 not applied (no terminal to ask), 130 declined.
//
// The building blocks are exported too (parseArgv, helpText, confirm, CliUsageError), so a script whose needs this
// wrapper does not cover can use the parser alone and do the rest its own way.
import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline/promises';

export class CliUsageError extends Error {}

const STANDARD = {
  help: { short: 'h', type: 'flag', help: 'Show this help and exit.' },
  dryRun: {
    name: 'dry-run', short: 'n', type: 'flag', kinds: ['change', 'destructive'],
    help: 'Print the plan and exit without changing anything.',
  },
  yes: {
    short: 'y', type: 'flag', kinds: ['change', 'destructive'],
    help: 'Apply without asking (CI, scripts, agents).',
  },
  verbose: { short: 'v', type: 'flag', help: 'Print more detail.' },
  quiet: { short: 'q', type: 'flag', help: 'Print errors only.' },
};

const camel = (s) => s.replace(/-([a-z0-9])/g, (_, c) => c.toUpperCase());
const kebab = (s) => s.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`);

/** The full option spec for a kind: the script's own options first, then the standard ones. */
export function withStandard(kind, options = {}) {
  const spec = {};
  for (const [key, o] of Object.entries(options)) spec[camel(key)] = { name: o.name || kebab(key), ...o };
  for (const [key, o] of Object.entries(STANDARD)) {
    if (spec[key] || (o.kinds && !o.kinds.includes(kind))) continue;
    spec[key] = { name: o.name || key, ...o };
  }
  return spec;
}

function toBool(name, v) {
  if (['1', 'true', 'yes', 'on'].includes(String(v))) return true;
  if (['0', 'false', 'no', 'off', ''].includes(String(v))) return false;
  throw new CliUsageError(`option --${name} takes no value or one of true/false, got '${v}'`);
}

/** Parse argv against a spec. Returns { opts, args }; throws CliUsageError on a mistake. */
export function parseArgv(argv, spec, { env = process.env } = {}) {
  const opts = {}, args = [], seen = new Set();
  const byName = new Map(), byShort = new Map();
  for (const [key, o] of Object.entries(spec)) {
    byName.set(o.name, key);
    if (o.short) byShort.set(o.short, key);
    let v = o.env && env[o.env] ? env[o.env] : o.default;
    if (o.type === 'flag') v = toBool(o.name, v ?? false);
    else if (o.type === 'list') v = v === undefined || v === '' ? [] : Array.isArray(v) ? v : String(v).split(',');
    opts[key] = v ?? (o.type === 'value' ? '' : v);
  }
  const queue = [...argv];
  while (queue.length) {
    const a = queue.shift();
    let key, val, has = false;
    if (a === '--') { args.push(...queue); break; }
    if (a.startsWith('--')) {
      const eq = a.indexOf('='), name = eq < 0 ? a.slice(2) : a.slice(2, eq);
      if (eq >= 0) { val = a.slice(eq + 1); has = true; }
      key = byName.get(name);
      if (!key && name.startsWith('no-') && !has && spec[byName.get(name.slice(3))]?.type === 'flag') {
        opts[byName.get(name.slice(3))] = false;
        continue;
      }
      if (!key) throw new CliUsageError(`unknown option --${name}`);
    } else if (a.length > 1 && a.startsWith('-')) {
      key = byShort.get(a[1]);
      if (!key) throw new CliUsageError(`unknown option -${a[1]}`);
      if (a[2] === '=') { val = a.slice(3); has = true; }
      else if (a.length > 2) {
        if (spec[key].type === 'flag') queue.unshift(`-${a.slice(2)}`);
        else { val = a.slice(2); has = true; }
      }
    } else { args.push(a); continue; }
    const o = spec[key];
    if (o.type === 'flag') { opts[key] = has ? toBool(o.name, val) : true; continue; }
    if (!has) {
      if (!queue.length) throw new CliUsageError(`option --${o.name} needs a value`);
      val = queue.shift();
    }
    if (o.type === 'list') { opts[key] = [...(seen.has(key) ? opts[key] : []), ...val.split(',')]; seen.add(key); }
    else opts[key] = val;
  }
  return { opts, args };
}

/** Help text: the header comment of the script file, then the options generated from the spec. */
export function helpText(file, spec) {
  const lines = fs.readFileSync(file, 'utf8').split('\n');
  const header = [];
  for (const [i, line] of lines.entries()) {
    if (i === 0 && line.startsWith('#!')) continue;
    if (!line.startsWith('//')) break;
    header.push(line.replace(/^\/\/ ?/, ''));
  }
  const rows = Object.values(spec).map((o) => {
    let left = `--${o.name}${o.type === 'value' ? ' <value>' : o.type === 'list' ? ' <a,b>' : ''}`;
    left = o.short ? `-${o.short}, ${left}` : `    ${left}`;
    let right = o.help || '';
    if (o.type === 'flag' && o.default) right += ` Default: on (--no-${o.name} turns it off).`;
    else if (o.type !== 'flag' && o.default !== undefined && o.default !== '') {
      right += ` Default: ${[].concat(o.default).join(',')}.`;
    }
    if (o.env) right += ` Env: ${o.env}.`;
    return `  ${left.padEnd(28)} ${right}`;
  });
  return `${header.join('\n')}\n\nOptions:\n${rows.join('\n')}\n`;
}

/** Ask on the terminal. typed: the answer must be the word "yes". */
export async function confirm(question, { typed = false, input = process.stdin, output = process.stderr } = {}) {
  const rl = readline.createInterface({ input, output });
  try {
    const answer = (await rl.question(question)).trim();
    return typed ? answer === 'yes' : /^(y|yes)$/i.test(answer);
  } finally {
    rl.close();
  }
}

/**
 * Parse the command line, handle --help and usage errors, and return the run helpers.
 * kind: 'read' runs directly; 'change' and 'destructive' get --dry-run and --yes, and apply() asks first.
 */
export function cli({
  kind = 'read', options = {}, args: argSpec = {},
  file = process.argv[1], argv = process.argv.slice(2), env = process.env,
} = {}) {
  if (!['read', 'change', 'destructive'].includes(kind)) {
    throw new Error(`cli: kind must be read, change or destructive, not '${kind}'`);
  }
  const name = path.basename(file || 'script');
  const spec = withStandard(kind, options);
  const before = argv.includes('--') ? argv.slice(0, argv.indexOf('--')) : argv;
  if (before.includes('-h') || before.includes('--help')) {
    process.stdout.write(helpText(file, spec));
    process.exit(0);
  }
  const usage = (msg) => { process.stderr.write(`${name}: ${msg}\nTry --help.\n`); process.exit(2); };
  let parsed;
  try {
    parsed = parseArgv(argv, spec, { env });
  } catch (e) {
    if (e instanceof CliUsageError) usage(e.message);
    throw e;
  }
  const { opts, args } = parsed;
  const { min = 0, max = Infinity, usage: argUsage = '' } = argSpec;
  if (args.length < min) usage(`missing argument: ${argUsage}`);
  if (args.length > max) usage(`too many arguments: ${args.slice(max).join(' ')}`);

  const plan = [];
  let started = Date.now();
  const info = (msg) => { if (!opts.quiet) console.log(msg); };
  return {
    opts, args, kind, name,
    info,
    debug: (msg) => { if (opts.verbose) console.error(msg); },
    warn: (msg) => console.error(`${name}: ${msg}`),
    fail: (msg, code = 1) => { console.error(`${name}: ${msg}`); process.exit(code); },
    usage,
    plan: (line) => plan.push(line),
    get planned() { return [...plan]; },
    async apply(title = 'Plan') {
      if (kind === 'read') throw new Error('apply() needs kind change or destructive');
      if (!plan.length) { info('Nothing to do.'); process.exit(0); }
      if (!(opts.yes && opts.quiet)) console.log(`${title}:\n${plan.map((l) => `  - ${l}`).join('\n')}`);
      if (opts.dryRun) { info('Dry run: nothing changed.'); process.exit(0); }
      if (!opts.yes) {
        if (!process.stdin.isTTY) {
          console.error(
            `${name}: not applied, there is no terminal to ask. Re-run with --yes to apply, or --dry-run to preview.`,
          );
          process.exit(3);
        }
        const ok = kind === 'destructive'
          ? await confirm('This cannot be undone. Type yes to apply: ', { typed: true })
          : await confirm('Apply? [y/N] ');
        if (!ok) { console.error('Not applied.'); process.exit(130); }
      }
      started = Date.now();
    },
    done: (msg = 'Done') => info(`${msg} in ${Math.round((Date.now() - started) / 1000)}s.`),
  };
}
