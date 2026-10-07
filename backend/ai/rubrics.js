// Rubrics live on the server (shared/rubrics/). Students only ever see the
// question; points, trap and follow-ups stay here.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
export const RUBRICS_DIR = process.env.RUBRICS_DIR ?? path.resolve(here, '../../shared/rubrics');

const ORDER = ['binary_search', 'factorial_recursive', 'normalisation'];

export function loadRubrics(dir = RUBRICS_DIR) {
  const list = fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.json'))
    .map((f) => JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8')));
  const rank = (id) => (ORDER.includes(id) ? ORDER.indexOf(id) : ORDER.length);
  list.sort((a, b) => rank(a.id) - rank(b.id) || a.id.localeCompare(b.id));
  return new Map(list.map((r) => [r.id, r]));
}

export const rubrics = loadRubrics();

/** The student-facing part of a rubric (contract 00). */
export function questionOf(r) {
  return {
    id: r.id,
    title: r.title,
    subject: r.subject ?? '',
    prompt: r.prompt,
    marks: r.marks ?? 10,
    points: r.points.length,
  };
}

/**
 * Editor shape (what the teacher edits) to stored rubric shape (what the
 * grader reads, same as shared/rubrics/). Point ids are assigned here.
 */
export function rubricFromDraft(id, d) {
  const points = d.points.map((p, i) => ({
    id: `kp${i + 1}`,
    statement: p.statement.trim(),
    weight: p.weight,
    hint: (p.hint ?? '').trim(),
  }));
  return {
    id,
    title: d.title.trim(),
    subject: (d.subject ?? '').trim(),
    prompt: d.prompt.trim(),
    marks: d.marks ?? 10,
    points,
    trap: { false_claim: d.trap.false_claim.trim(), truth: d.trap.truth.trim() },
    follow_ups: {
      probe: Object.fromEntries(
        d.points.map((p, i) => [`kp${i + 1}`, (p.probe ?? '').trim()]).filter(([, q]) => q),
      ),
      what_if: d.what_if.trim(),
    },
  };
}
