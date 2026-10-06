/**
 * A4 - Scoring functions
 *
 * Scores student understanding against rubric key points.
 */

/**
 * Clamp a number to the 0-100 range.
 */
function clampScore(value) {
  return Math.max(0, Math.min(100, Math.round(value)));
}

/**
 * Calculate an understanding score from key-point statuses.
 *
 * Statuses:
 * - solid
 * - partial
 * - missing
 *
 * solid   = 100%
 * partial = 50%
 * missing = 0%
 */
export function scoreUnderstanding(keyPoints = []) {
  if (!Array.isArray(keyPoints) || keyPoints.length === 0) {
    return 0;
  }

  const total = keyPoints.reduce((sum, point) => {
    if (point.status === 'solid') return sum + 1;
    if (point.status === 'partial') return sum + 0.5;
    return sum;
  }, 0);

  return clampScore((total / keyPoints.length) * 100);
}

/**
 * Score one viva turn.
 *
 * The turn score is based on the key-point statuses supplied
 * by the evaluator/LLM.
 */
export function scoreTurn({ keyPoints = [], trapCaught = false } = {}) {
  const understandingScore = scoreUnderstanding(keyPoints);

  // Trap handling is intentionally a small bonus/penalty.
  const trapAdjustment = trapCaught ? 5 : 0;

  return {
    score: clampScore(understandingScore + trapAdjustment),
    understanding_score: understandingScore,
    trap_caught: Boolean(trapCaught),
  };
}
