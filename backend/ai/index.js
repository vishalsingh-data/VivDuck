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

// ── buildReport example return ────────────────────────────────────────────────
// NOTE: shared/contracts/03_report.json does not exist yet in this repo;
// the shape below mirrors the summary written into state by nextTurn and
// the evaluation fields from 04_evaluation_result.json.
const REPORT_EXAMPLE = {
  score_before: 54,
  score_after: 79,
  bloom_reached: 'Analyse',
  trap_caught: true,
  weakest_key_point: 'Off-by-one and mid-point edge cases',
  rubric_id: null,
  assessment: [
    { key_point_id: 'kp_correctness', status: 'met' },
    { key_point_id: 'kp_edge_cases',  status: 'partial' },
    { key_point_id: 'kp_complexity',  status: 'met' },
    { key_point_id: 'kp_trap',        status: 'caught' },
  ],
};

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
        assessment: [
          { key_point_id: 'kp_correctness', status: 'met' },
          { key_point_id: 'kp_edge_cases',  status: 'partial' },
          { key_point_id: 'kp_complexity',  status: 'met' },
          { key_point_id: 'kp_trap',        status: 'caught' },
        ],
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
 * @returns {object} Report response object.
 */
export async function buildReport(state) {
  // Return state.summary if populated, otherwise fall back to the static example.
  return {
    ...REPORT_EXAMPLE,
    ...(state.summary ?? {}),
    rubric_id: state.sampleId ?? REPORT_EXAMPLE.rubric_id,
  };
}
