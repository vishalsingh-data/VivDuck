// STUB. Track A replaces the inside of these functions.
// The names, arguments and return shapes must not change.

// ── Fixed probe/what_if/trap questions ───────────────────────────────────────
const FIXED_QUESTIONS = [
  {
    questionType: 'probe',
    question:
      'Can you walk me through what happens in your code when the target value is not present in the array?',
  },
  {
    questionType: 'what_if',
    question:
      'What would happen to your algorithm if the input array were not sorted?',
  },
  {
    questionType: 'trap',
    question:
      'Your midpoint is computed as (lo + hi) // 2. Why might writing (lo + hi) / 2 cause a problem in languages like Java or C?',
  },
];

// ── Report example — embedded from shared/contracts/03_report.json ────────────
// Do NOT read the contracts folder at runtime; values are inlined here.
const REPORT_EXAMPLE = {
  session_id: 's_k3f9',
  title: 'Binary search',
  score_before: 54,
  score_after: 79,
  bloom_reached: 'Analyse',
  trap_caught: true,
  trap_explanation:
    'The student correctly identified that (lo + hi) / 2 can overflow in fixed-width integer languages.',
  weakest_key_point: 'Off-by-one and mid-point edge cases',
  key_points: [
    {
      id: 'kp1',
      statement: 'The input array must be sorted for binary search to work correctly.',
      status: 'solid',
      evidence_quote:
        'It would not work correctly on an unsorted array — the halving logic assumes order.',
    },
    {
      id: 'kp2',
      statement: 'The lo and hi pointers shrink the search window on every iteration.',
      status: 'solid',
      evidence_quote: 'lo = mid + 1 and hi = mid - 1 move the window closer each time.',
    },
    {
      id: 'kp3',
      statement: 'The midpoint value is compared with the target to decide which half to search.',
      status: 'partial',
      evidence_quote: "I compare arr[mid] to the target, but I wasn't sure about the equal case.",
    },
    {
      id: 'kp4',
      statement: 'The loop continues while lo is less than or equal to hi.',
      status: 'missing',
      evidence_quote: null,
    },
    {
      id: 'kp5',
      statement: 'The function returns -1 when the target is not found.',
      status: 'solid',
      evidence_quote: 'It returns -1 when the loop ends without finding the target.',
    },
    {
      id: 'kp6',
      statement: 'Binary search runs in O(log n) time.',
      status: 'partial',
      evidence_quote:
        "I think it's log n because we halve the list each time, but I couldn't prove it.",
    },
  ],
  strengths: [
    'Correctly implemented the iterative loop with shrinking bounds.',
    'Identified that an unsorted input breaks the algorithm.',
    'Caught the integer-overflow trap for fixed-width languages.',
  ],
  gaps: [
    'Could not articulate the loop-termination condition (lo <= hi) unprompted.',
    'Incomplete explanation of the midpoint comparison for the equal case.',
    'Did not state the O(log n) time complexity without prompting.',
  ],
  review_next: [
    'Loop invariants and termination conditions in binary search.',
    'Formal proof of O(log n) complexity.',
    'Edge cases: empty array, single-element array, duplicate values.',
  ],
  paste_flags: 0,
};

// Assessment list derived from key_points in the report example above.
const REPORT_ASSESSMENT = REPORT_EXAMPLE.key_points.map(({ id, status }) => ({
  key_point_id: id,
  status,
}));

// ── Public API ────────────────────────────────────────────────────────────────

/**
 * Start a new viva session.
 * @param {{ submission: string, kind: string, language: string, sampleId: string|null }} _opts
 * @returns {object} state
 */
export async function startSession({ submission, kind, language, sampleId } = {}) {
  return {
    round: 0,
    turns: [],
    submission,
    kind,
    language,
    sampleId: sampleId ?? null,
    summary: null,
  };
}

/**
 * Advance the viva by one student turn.
 * @param {object} state  - The state object returned by startSession or a previous nextTurn.
 * @param {string} studentText - The student's latest message.
 * @returns {{ state: object, question: string|null, questionType: string|null, round: number, done: boolean }}
 */
export async function nextTurn(state, studentText) {
  // Save this turn
  const turn = { role: 'student', text: studentText, round: state.round + 1 };
  const updatedTurns = [...state.turns, turn];
  const nextRound = state.round + 1;

  // After three student messages we have asked all three questions; the fourth
  // message ends the session.
  if (nextRound >= 4) {
    const finalState = {
      ...state,
      turns: updatedTurns,
      round: nextRound,
      summary: {
        score_before: 54,
        score_after: 79,
        bloom_reached: 'Analyse',
        trap_caught: true,
        weakest_key_point: 'Off-by-one and mid-point edge cases',
        rubric_id: state.sampleId ?? null,
        assessment: REPORT_ASSESSMENT,
      },
    };
    return { state: finalState, question: null, questionType: null, round: nextRound, done: true };
  }

  // Rounds 1-3: return the corresponding fixed question
  const { question, questionType } = FIXED_QUESTIONS[nextRound - 1];
  const updatedState = { ...state, turns: updatedTurns, round: nextRound };
  return { state: updatedState, question, questionType, round: nextRound, done: false };
}

/**
 * Build the final report for the session.
 * @param {object} state - Completed session state (after done === true).
 * @returns {object} Report response object matching shared/contracts/03_report.json.
 */
export async function buildReport(state) {
  // Return the full report example with session_id and rubric_id resolved from state.
  return {
    ...REPORT_EXAMPLE,
    session_id: state.sessionId ?? REPORT_EXAMPLE.session_id,
    rubric_id: state.sampleId ?? null,
  };
}
