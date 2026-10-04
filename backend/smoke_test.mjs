// smoke_test.mjs - verifies startSession + nextTurn + buildReport stub behaviour
// Usage: node smoke_test.mjs  (run from backend/)
import { startSession, nextTurn, buildReport } from './ai/index.js';

const SAMPLE_CODE = `def binary_search(arr, target):
    lo, hi = 0, len(arr) - 1
    while lo <= hi:
        mid = (lo + hi) // 2
        if arr[mid] == target:
            return mid
        elif arr[mid] < target:
            lo = mid + 1
        else:
            hi = mid - 1
    return -1
`;

const STUDENT_ANSWERS = [
  'It returns -1 when the target is not found.',
  'It would not work correctly on an unsorted array.',
  'Integer overflow could occur with large numbers.',
  'I think I handled all the edge cases.',
];

let state = await startSession({
  submission: SAMPLE_CODE,
  kind: 'viva',
  language: 'python',
  sampleId: 'binary_search',
});

console.log('--- startSession ---');
console.log('round:', state.round);
console.log('turns:', state.turns.length);
console.log('');

for (let i = 0; i < 4; i++) {
  const result = await nextTurn(state, STUDENT_ANSWERS[i]);
  state = result.state;
  console.log(`--- nextTurn ${i + 1} ---`);
  console.log('round:', result.round);
  console.log('questionType:', result.questionType);
  console.log('question:', result.question);
  console.log('done:', result.done);
  console.log('');
}

// Call buildReport after the session is done
const report = await buildReport(state);
console.log('--- buildReport ---');
console.log('score_before:', report.score_before);
console.log('score_after:', report.score_after);
console.log('key_points count:', report.key_points.length);
console.log('');
