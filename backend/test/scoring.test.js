import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

import { quoteFound, verifyPoints, score, mergeUp, reviewOf, agreement } from '../ai/scoring.js';
import { rubrics } from '../ai/rubrics.js';

const rubric = rubrics.get('binary_search');
const answer = 'Binary search only works on a sorted list. It looks at the middle element.';

test('quotes must appear verbatim, ignoring case, spacing and smart quotes', () => {
  assert.ok(quoteFound('binary search only works on a  sorted list.', [answer]));
  assert.ok(quoteFound('“It looks at the middle element”', [answer]));
  assert.ok(!quoteFound('Binary search needs a sorted list.', [answer]));
  assert.ok(!quoteFound('', [answer]));
});

test('a point whose quote is not in the answer is set to missing', () => {
  const { points, failed } = verifyPoints(
    rubric,
    [
      { id: 'kp1', status: 'solid', evidence_quote: 'Binary search only works on a sorted list.', comment: 'Good.' },
      { id: 'kp2', status: 'solid', evidence_quote: 'It compares the target with the middle.', comment: 'Good.' },
    ],
    [answer],
  );
  assert.equal(points[0].status, 'solid');
  assert.equal(points[1].status, 'missing');
  assert.equal(points[1].evidence_quote, null);
  assert.deepEqual(failed, ['kp2']);
  assert.equal(points.length, rubric.points.length, 'unlabelled points still appear, as missing');
});

test('score is weighted: solid full, partial half', () => {
  const pts = rubric.points.map((p, i) => ({ ...p, status: i === 0 ? 'solid' : i === 1 ? 'partial' : 'missing' }));
  // weights 3,3,2,2,2,1 = 13; got 3 + 1.5 = 4.5
  assert.equal(score(pts), Math.round((100 * 4.5) / 13));
});

test('follow-ups can only raise a point', () => {
  const before = [{ id: 'a', status: 'solid' }, { id: 'b', status: 'missing' }];
  const after = [{ id: 'a', status: 'missing' }, { id: 'b', status: 'partial' }];
  assert.deepEqual(mergeUp(before, after).map((p) => p.status), ['solid', 'partial']);
});

test('review reasons follow the contract codes', () => {
  const r = reviewOf({ runs: [40, 60], evidenceFailed: 1, pasted: true, transcription: { legibility: 'unclear' } });
  assert.deepEqual(r.reasons.map((x) => x.code), ['evidence_check', 'runs_differ', 'pasted', 'handwriting']);
  assert.equal(reviewOf({ runs: [70, 78] }).needs_review, false);
});

test('agreement matches the contract sample', () => {
  const c = JSON.parse(fs.readFileSync(new URL('../../shared/contracts/04_teacher_summary.json', import.meta.url)));
  assert.deepEqual(agreement(c.response.sessions), c.response.agreement);
});
