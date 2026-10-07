// Offline stand-in for the model, used when no API key is configured (local
// dev, tests, a demo with no network). It produces the same raw labels the
// model would, so they go through the same evidence check and scoring rules.

const SENTENCE_BREAK = /(?<=[.!?])\s+|\n+/;
const DISAGREE =
  /\b(no|not|false|wrong|incorrect|disagree|isn't|doesn't|can't|cannot|won't|untrue)\b/i;

export function sentences(text) {
  return String(text ?? '')
    .split(SENTENCE_BREAK)
    .map((s) => s.trim())
    .filter(Boolean);
}

export function wordCount(text) {
  const t = String(text ?? '').trim();
  return t ? t.split(/\s+/).length : 0;
}

/**
 * Labels each rubric point from keyword hits. [strict] is the second,
 * independent run: it needs more evidence before calling a point solid.
 */
export function labelPoints(rubric, texts, { strict = false } = {}) {
  return rubric.points.map((p) => {
    const keywords = (p.mock_keywords ?? []).map((k) => k.toLowerCase());
    const found = new Set();
    let best = null;
    let bestHits = 0;
    for (const t of texts) {
      for (const s of sentences(t)) {
        const lower = s.toLowerCase();
        const hits = keywords.filter((k) => lower.includes(k));
        hits.forEach((h) => found.add(h));
        if (hits.length > bestHits) {
          bestHits = hits.length;
          best = s;
        }
      }
    }
    const solidAt = strict ? 3 : 2;
    const status = found.size >= solidAt ? 'solid' : found.size >= 1 ? 'partial' : 'missing';
    return { id: p.id, status, evidence_quote: status === 'missing' ? '' : best, comment: '' };
  });
}

export function caughtTrap(reply) {
  return DISAGREE.test(reply ?? '');
}

export function bloomOf(replies, trapCaught) {
  let level = 'Remember';
  if (wordCount(replies[0]) >= 8) level = 'Understand';
  if (wordCount(replies[1]) >= 8) level = 'Apply';
  if (trapCaught) level = 'Analyse';
  return level;
}

/** What a student might plausibly write by hand, with one unreadable word. */
export const HANDWRITTEN = {
  binary_search:
    'Binary search needs the list to be sorted first. It checks the middle element and compares it with the [?] we want. If the target is smaller it throws away the right half, if bigger the left half. It repeats until it finds it or the list is empty, then it says not found. This is why it takes log n steps.',
  factorial_recursive:
    'Recursion is when a function calls itself on a smaller problem. For factorial the base case is n == 0 which returns 1. Otherwise it returns n times factorial(n - 1). The calls wait on the [?] until the base case is reached and then they unwind.',
  normalisation:
    'Normalisation is used to remove redundant data so we do not get update anomalies. 1NF means every column has atomic values. 2NF means there is no partial dependency on part of a composite key. 3NF removes [?] dependencies between non-key columns.',
};
