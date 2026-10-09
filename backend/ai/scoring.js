// Deterministic rules. The AI only labels evidence; everything in this file
// decides what those labels are worth. No model calls here.

export const STATUSES = ['solid', 'partial', 'missing'];
const RANK = { missing: 0, partial: 1, solid: 2 };
const CREDIT = { solid: 1, partial: 0.5, missing: 0 };

/** Max gap between the two grading runs before a teacher should look. */
export const RUNS_DIFFER_LIMIT = 10;

export const REVIEW_MESSAGES = {
  evidence_check: 'A quote was not found in the answer, so that point was set to missing.',
  runs_differ: 'The two grading runs differ by more than 10 points.',
  pasted: 'The answer was pasted.',
  handwriting: 'The handwriting was hard to read.',
  ai_rubric: "The student asked their own question, so the rubric was drafted by AI and hasn't been checked by a teacher.",
};

// ── Evidence check ───────────────────────────────────────────────────────────

/** Folds the differences a copy-paste can't be blamed for: case, spacing, smart quotes. */
export function normalise(text) {
  return String(text ?? '')
    .normalize('NFKC')
    .toLowerCase()
    .replace(/[‘’`]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/[–—]/g, '-')
    .replace(/\s+/g, ' ')
    .trim();
}

function trimQuote(q) {
  return normalise(q)
    .replace(/^["'.…\s]+/, '')
    .replace(/["'…\s]+$/, '')
    .replace(/\.{3}$/, '')
    .trim();
}

/** True when [quote] appears word for word in one of the student's [texts]. */
export function quoteFound(quote, texts) {
  const q = trimQuote(quote);
  if (q.length < 3) return false;
  const bare = q.replace(/[.!?,;:]+$/, '');
  return texts.some((t) => {
    const hay = normalise(t);
    return hay.includes(q) || hay.includes(bare);
  });
}

/**
 * Turns raw labels (from the model or the keyword grader) into graded points.
 * Every solid or partial point must carry a quote that is really in [texts];
 * one that doesn't is set to missing and reported.
 */
export function verifyPoints(rubric, labels, texts) {
  const byId = new Map((labels ?? []).map((l) => [l.id, l]));
  const failed = [];
  const points = rubric.points.map((p) => {
    const l = byId.get(p.id);
    let status = STATUSES.includes(l?.status) ? l.status : 'missing';
    let quote = (l?.evidence_quote ?? '').trim() || null;
    let comment = (l?.comment ?? '').trim() || defaultComment(status, p);
    if (status !== 'missing' && !quoteFound(quote, texts)) {
      failed.push(p.id);
      status = 'missing';
      comment = `The quoted evidence was not found in the answer, so this point was not credited. ${p.hint ?? ''}`.trim();
    }
    if (status === 'missing') quote = null;
    return { id: p.id, statement: p.statement, weight: p.weight, status, comment, evidence_quote: quote };
  });
  return { points, failed };
}

export function defaultComment(status, p) {
  const hint = p.hint ?? '';
  if (status === 'solid') return 'Covered clearly.';
  if (status === 'partial') return `Partly covered. ${hint}`.trim();
  return `Not covered. ${hint}`.trim();
}

// ── Marks ────────────────────────────────────────────────────────────────────

/** Weighted rubric score out of 100: solid = full weight, partial = half. */
export function score(points) {
  const total = points.reduce((a, p) => a + p.weight, 0);
  if (total === 0) return 0;
  const got = points.reduce((a, p) => a + p.weight * CREDIT[p.status], 0);
  return Math.round((100 * got) / total);
}

/** A 0-100 score as marks out of [max], to the nearest half mark. */
export function marksOf(score, max) {
  return Math.round((score / 100) * max * 2) / 2;
}

/** Heaviest missing point, else heaviest partial, else heaviest overall. */
export function weakest(points) {
  for (const s of ['missing', 'partial']) {
    const c = points.filter((p) => p.status === s).sort((a, b) => b.weight - a.weight);
    if (c.length) return c[0];
  }
  return [...points].sort((a, b) => b.weight - a.weight)[0];
}

/** Follow-ups add evidence; they never take marks away. */
export function mergeUp(before, after) {
  return before.map((b, i) => (RANK[after[i].status] > RANK[b.status] ? after[i] : b));
}

// ── Review flags ─────────────────────────────────────────────────────────────

export function reviewOf({ runs, evidenceFailed = 0, pasted = false, transcription = null, aiRubric = false }) {
  const reasons = [];
  if (evidenceFailed > 0) {
    reasons.push({
      code: 'evidence_check',
      message:
        evidenceFailed === 1
          ? REVIEW_MESSAGES.evidence_check
          : `${evidenceFailed} quotes were not found in the answer, so those points were set to missing.`,
    });
  }
  const gap = Math.abs(runs[0] - runs[1]);
  if (gap > RUNS_DIFFER_LIMIT) {
    reasons.push({
      code: 'runs_differ',
      message: `The two grading runs differ by ${gap} points (${runs[0]} and ${runs[1]}).`,
    });
  }
  if (pasted) reasons.push({ code: 'pasted', message: REVIEW_MESSAGES.pasted });
  if (transcription && transcription.legibility === 'unclear') {
    reasons.push({ code: 'handwriting', message: REVIEW_MESSAGES.handwriting });
  }
  if (aiRubric) reasons.push({ code: 'ai_rubric', message: REVIEW_MESSAGES.ai_rubric });
  return { needs_review: reasons.length > 0, reasons };
}

// ── Report text ──────────────────────────────────────────────────────────────

export function feedbackLists(rubric, points) {
  const hints = Object.fromEntries(rubric.points.map((p) => [p.id, p.hint]));
  const solid = points.filter((p) => p.status === 'solid');
  const weak = points.filter((p) => p.status !== 'solid').sort((a, b) => b.weight - a.weight);
  return {
    strengths: solid.slice(0, 3).map((p) => p.statement),
    gaps: weak.slice(0, 3).map((p) => p.statement),
    review_next: weak.slice(0, 3).map((p) => hints[p.id]).filter(Boolean),
  };
}

export function weakestStatement(points) {
  return points.every((p) => p.status === 'solid') ? 'None' : weakest(points).statement;
}

// ── Class agreement ──────────────────────────────────────────────────────────

/** Compares teacher marks with VivDuck's score_before. */
export function agreement(sessions) {
  const scored = sessions.filter((s) => s.teacher_score != null);
  if (scored.length === 0) return { sample_size: 0, mean_abs_diff: 0, within_10_pct: 0 };
  const diffs = scored.map((s) => Math.abs(s.teacher_score - s.score_before));
  const mean = diffs.reduce((a, d) => a + d, 0) / diffs.length;
  return {
    sample_size: scored.length,
    mean_abs_diff: Math.round(mean * 10) / 10,
    within_10_pct: Math.round((100 * diffs.filter((d) => d <= 10).length) / diffs.length),
  };
}
