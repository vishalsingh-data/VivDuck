#!/usr/bin/env node
/**
 * check-ownership.mjs
 * Usage: node scripts/check-ownership.mjs <branch>
 *
 * Runs `git diff --name-only main...<branch>` and verifies that every
 * changed file is inside the paths permitted for that branch according to
 * scripts/ownership.json.
 *
 * Exits 0 (prints PASS) when all files are within allowed paths.
 * Exits 1 (prints FAIL + offending files) otherwise.
 */

import { execSync } from 'child_process';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import path from 'path';

// ── resolve paths ─────────────────────────────────────────────────────────────
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ownershipPath = path.join(__dirname, 'ownership.json');

// ── read arguments ────────────────────────────────────────────────────────────
let branch = process.argv[2];
if (!branch) {
  console.error('Usage: node scripts/check-ownership.mjs <branch>');
  process.exit(1);
}

// Strip optional "origin/" prefix
branch = branch.replace(/^origin\//, '');

// ── load ownership map ────────────────────────────────────────────────────────
const ownership = JSON.parse(readFileSync(ownershipPath, 'utf8'));

if (!ownership[branch]) {
  console.error(`ERROR: Branch "${branch}" is not defined in ownership.json`);
  process.exit(1);
}

const allowedPaths = ownership[branch]; // e.g. ["backend/ai/"]

// ── get changed files ─────────────────────────────────────────────────────────
let diffOutput;
try {
  diffOutput = execSync(`git diff --name-only main...${branch}`, {
    encoding: 'utf8',
    // include stderr so git errors surface
    stdio: ['pipe', 'pipe', 'pipe'],
  });
} catch (err) {
  console.error('ERROR running git diff:');
  console.error(err.stderr || err.message);
  process.exit(1);
}

const changedFiles = diffOutput
  .split('\n')
  .map(f => f.trim())
  .filter(Boolean);

// ── check each file ───────────────────────────────────────────────────────────
/**
 * Returns true when `file` is inside at least one of the allowed paths.
 * A path ending with "/" is treated as a directory prefix.
 * A path without "/" at the end must match exactly.
 */
function isAllowed(file, allowed) {
  return allowed.some(p => {
    if (p.endsWith('/')) {
      // directory prefix
      return file === p.slice(0, -1) || file.startsWith(p);
    }
    // exact file match
    return file === p;
  });
}

const violations = changedFiles.filter(f => !isAllowed(f, allowedPaths));

// ── report ────────────────────────────────────────────────────────────────────
if (violations.length > 0) {
  console.log('FAIL');
  violations.forEach(f => console.log(`  ${f}`));
  process.exit(1);
} else {
  console.log('PASS');
  process.exit(0);
}
