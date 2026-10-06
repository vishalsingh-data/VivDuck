import { z } from 'zod';

import { callJson } from './llm.js';

import {
  buildRubricPrompt,
  buildProbePrompt,
  buildWhatIfPrompt,
  buildTrapPrompt,
} from './prompts.js';

import {
  RubricSchema,
} from './schemas.js';

import {
  scoreUnderstanding,
  scoreTurn,
} from './scoring.js';

import { BINARY_SEARCH_SAMPLE } from './samples.js';


// ------------------------------------------------------------
// A5 – Viva Engine
// ------------------------------------------------------------

const QUESTION_SCHEMA = z.object({
  question: z.string().min(1),
});

const EVALUATION_SCHEMA = z.object({
  key_points: z.array(
    z.object({
      key_point_id: z.string(),
      status: z.enum(['solid', 'partial', 'missing']),
      evidence_quote: z.string().default(''),
    })
  ),
  trap_caught: z.boolean().default(false),
  bloom_reached: z
    .enum([
      'Remember',
      'Understand',
      'Apply',
      'Analyse',
      'Evaluate',
      'Create',
    ])
    .default('Understand'),
  strengths: z.array(z.string()).default([]),
  gaps: z.array(z.string()).default([]),
});


// ------------------------------------------------------------
// Fallback questions
// ------------------------------------------------------------

const FALLBACK_QUESTIONS = {
  probe:
    'Can you explain how your code works step by step and why the main decisions in your solution are correct?',

  what_if:
    'What would happen if an important assumption of your solution were changed? Explain what would break and why.',

  trap:
    'What is one hidden edge case or limitation in your solution that could cause an incorrect result?',
};


// ------------------------------------------------------------
// Utility helpers
// ------------------------------------------------------------

function clampScore(value) {
  return Math.max(0, Math.min(100, Math.round(value)));
}

function getSample(sampleId) {
  if (sampleId === BINARY_SEARCH_SAMPLE.id) {
    return BINARY_SEARCH_SAMPLE;
  }

  return null;
}

function mergeKeyPointStatuses(existing = [], incoming = []) {
  const rank = {
    missing: 0,
    partial: 1,
    solid: 2,
  };

  const merged = new Map();

  for (const point of existing) {
    merged.set(point.key_point_id, point);
  }

  for (const point of incoming) {
    const previous = merged.get(point.key_point_id);

    if (!previous || rank[point.status] > rank[previous.status]) {
      merged.set(point.key_point_id, point);
    }
  }

  return [...merged.values()];
}

function findWeakestKeyPoint(rubric, keyPoints) {
  const rank = {
    missing: 0,
    partial: 1,
    solid: 2,
  };

  let weakest = null;

  for (const point of rubric.key_points) {
    const result = keyPoints.find(
      (item) => item.key_point_id === point.id
    );

    const status = result?.status ?? 'missing';

    if (
      !weakest ||
      rank[status] < rank[weakest.status]
    ) {
      weakest = {
        id: point.id,
        statement: point.statement,
        status,
      };
    }
  }

  return weakest;
}


// ------------------------------------------------------------
// Generate a question using Gemini
// ------------------------------------------------------------

async function generateQuestion(prompt, fallback) {
  try {
    const result = await callJson({
      system:
        'You are a strict but helpful viva examiner. Generate exactly one concise viva question. Return JSON only.',

      user: `${prompt}

Return this JSON:
{
  "question": "your single viva question"
}`,

      schema: QUESTION_SCHEMA,
    });

    return result.question.trim();
  } catch (error) {
    console.warn(
      `Question generation failed. Using fallback question: ${error.message}`
    );

    return fallback;
  }
}


// ------------------------------------------------------------
// Evaluate one student answer
// ------------------------------------------------------------

async function evaluateAnswer({
  submission,
  rubric,
  question,
  questionType,
  studentText,
}) {
  const evaluationPrompt = `
You are evaluating a student's viva answer.

Student submission:
${submission}

Viva question type:
${questionType}

Viva question:
${question}

Student answer:
${studentText}

Rubric:
${JSON.stringify(rubric)}

Evaluate ONLY what the student actually demonstrated.

For every rubric key point:
- solid = clearly and correctly demonstrated
- partial = partly correct, vague, or incomplete
- missing = not demonstrated or incorrect

For a trap question:
trap_caught=true only when the student identifies and correctly explains the underlying misconception, edge case, limitation, or hidden assumption.

Do not give credit simply because the student repeats words from the rubric.

Return:
{
  "key_points": [
    {
      "key_point_id": "kp1",
      "status": "solid|partial|missing",
      "evidence_quote": "short evidence from the student's answer"
    }
  ],
  "trap_caught": true,
  "bloom_reached": "Remember|Understand|Apply|Analyse|Evaluate|Create",
  "strengths": [],
  "gaps": []
}
`;

  try {
    return await callJson({
      system:
        'You are an objective viva evaluator. Do not invent evidence. Return only valid JSON.',

      user: evaluationPrompt,

      schema: EVALUATION_SCHEMA,
    });
  } catch (error) {
    console.warn(
      `Answer evaluation failed: ${error.message}`
    );

    // Safe fallback: do not award unsupported credit.
    return {
      key_points: rubric.key_points.map((point) => ({
        key_point_id: point.id,
        status: 'missing',
        evidence_quote: '',
      })),

      trap_caught: false,

      bloom_reached: 'Understand',

      strengths: [],

      gaps: ['The answer could not be evaluated.'],
    };
  }
}


// ------------------------------------------------------------
// Build final summary
// ------------------------------------------------------------

function buildSummary(state) {
  const allEvaluations = state.evaluations ?? [];

  const mergedKeyPoints = mergeKeyPointStatuses(
    [],
    allEvaluations.flatMap(
      (evaluation) => evaluation.key_points
    )
  );

  const weakest = findWeakestKeyPoint(
    state.rubric,
    mergedKeyPoints
  );

  const finalKeyPoints = state.rubric.key_points.map(
    (point) => {
      const result = mergedKeyPoints.find(
        (item) => item.key_point_id === point.id
      );

      return {
        key_point_id: point.id,
        status: result?.status ?? 'missing',
        evidence_quote: result?.evidence_quote ?? '',
      };
    }
  );

  const understandingScore =
    scoreUnderstanding(finalKeyPoints);

  const trapCaught = allEvaluations.some(
    (evaluation) => evaluation.trap_caught
  );

  const finalTurnScore = scoreTurn({
    keyPoints: finalKeyPoints,
    trapCaught,
  });

  const initialEvaluation =
    allEvaluations[0] ?? null;

  const initialKeyPoints =
    initialEvaluation?.key_points ?? [];

  const scoreBefore =
    scoreUnderstanding(
      state.rubric.key_points.map((point) => {
        const result = initialKeyPoints.find(
          (item) => item.key_point_id === point.id
        );

        return {
          status: result?.status ?? 'missing',
        };
      })
    );

  const scoreAfter = finalTurnScore.score;

  const strengths = [
    ...new Set(
      allEvaluations.flatMap(
        (evaluation) => evaluation.strengths
      )
    ),
  ].slice(0, 5);

  const gaps = [
    ...new Set(
      allEvaluations.flatMap(
        (evaluation) => evaluation.gaps
      )
    ),
  ].slice(0, 5);

  const bloomOrder = [
    'Remember',
    'Understand',
    'Apply',
    'Analyse',
    'Evaluate',
    'Create',
  ];

  let bloomReached = 'Remember';

  for (const evaluation of allEvaluations) {
    if (
      bloomOrder.indexOf(evaluation.bloom_reached) >
      bloomOrder.indexOf(bloomReached)
    ) {
      bloomReached = evaluation.bloom_reached;
    }
  }

  const reviewNext = [];

  if (weakest) {
    if (weakest.status === 'missing') {
      reviewNext.push(
        `Review: ${weakest.statement}`
      );
    } else if (weakest.status === 'partial') {
      reviewNext.push(
        `Strengthen your understanding of: ${weakest.statement}`
      );
    }
  }

  if (gaps.length > 0) {
    reviewNext.push(...gaps.slice(0, 2));
  }

  if (reviewNext.length === 0) {
    reviewNext.push(
      'Review the main concepts and edge cases of the submitted solution.'
    );
  }

  return {
    score_before: clampScore(scoreBefore),
    score_after: clampScore(scoreAfter),

    bloom_reached: bloomReached,

    trap_caught: trapCaught,

    weakest_key_point:
      weakest?.statement ??
      'No weak key point identified.',

    rubric_id: state.sampleId ?? null,

    assessment: finalKeyPoints,

    strengths,

    gaps,

    review_next: reviewNext,

    paste_flags: 0,
  };
}


// ------------------------------------------------------------
// PUBLIC API
// ------------------------------------------------------------

/**
 * Start a viva session.
 */
export async function startSession({
  submission,
  kind,
  language,
  sampleId,
} = {}) {
  if (!submission) {
    throw new Error('submission is required');
  }

  let rubric;

  const sample = getSample(sampleId);

  // Use the supplied sample rubric when available.
  if (sample) {
    rubric = RubricSchema.parse(sample.rubric);
  } else {
    // Otherwise generate a rubric with Gemini.
    const rubricResult = await callJson({
      system:
        'You are an expert viva examiner. Create a concise assessment rubric. Return only valid JSON.',

      user: buildRubricPrompt({
        submission,
        language,
        kind,
      }),

      schema: RubricSchema,
    });

    rubric = rubricResult;
  }

  return {
    round: 0,

    turns: [],

    submission,

    kind,

    language,

    sampleId: sampleId ?? null,

    rubric,

    evaluations: [],

    questions: [],

    summary: null,

    sessionId: null,
  };
}


/**
 * Advance the viva by one student turn.
 *
 * Round 0:
 *   Student's initial explanation
 *   -> generate probe
 *
 * Round 1:
 *   Probe answer
 *   -> generate what-if
 *
 * Round 2:
 *   What-if answer
 *   -> generate trap
 *
 * Round 3:
 *   Trap answer
 *   -> finish viva
 */
export async function nextTurn(
  state,
  studentText
) {
  if (!state) {
    throw new Error('state is required');
  }

  if (!studentText || !studentText.trim()) {
    throw new Error('studentText is required');
  }

  if (state.summary) {
    return {
      state,
      question: null,
      questionType: null,
      round: state.round,
      done: true,
    };
  }

  const currentRound = state.round;

  const studentTurn = {
    role: 'student',
    text: studentText,
    round: currentRound + 1,
  };

  const updatedTurns = [
    ...state.turns,
    studentTurn,
  ];

  // ----------------------------------------------------------
  // Evaluate the answer that was just submitted.
  // ----------------------------------------------------------

  let updatedEvaluations = [
    ...(state.evaluations ?? []),
  ];

  if (currentRound >= 0) {
    const previousQuestion =
      state.questions?.[state.questions.length - 1];

    const questionType =
      previousQuestion?.questionType ??
      'probe';

    const question =
      previousQuestion?.question ??
      'Explain your submission.';

    const evaluation = await evaluateAnswer({
      submission: state.submission,
      rubric: state.rubric,
      question,
      questionType,
      studentText,
    });

    updatedEvaluations.push(evaluation);
  }

  const nextRound = currentRound + 1;

  // ----------------------------------------------------------
  // After initial explanation + 3 viva questions, finish.
  // ----------------------------------------------------------

  if (nextRound >= 4) {
    const finalState = {
      ...state,

      turns: updatedTurns,

      round: nextRound,

      evaluations: updatedEvaluations,

      summary: buildSummary({
        ...state,
        turns: updatedTurns,
        round: nextRound,
        evaluations: updatedEvaluations,
      }),
    };

    return {
      state: finalState,

      question: null,

      questionType: null,

      round: nextRound,

      done: true,
    };
  }

  // ----------------------------------------------------------
  // Generate the next viva question.
  // ----------------------------------------------------------

  let questionType;

  let prompt;

  let fallback;

  if (nextRound === 1) {
    questionType = 'probe';

    prompt = buildProbePrompt({
      submission: state.submission,
      rubric: state.rubric,
    });

    fallback = FALLBACK_QUESTIONS.probe;
  } else if (nextRound === 2) {
    questionType = 'what_if';

    prompt = buildWhatIfPrompt({
      submission: state.submission,
      rubric: state.rubric,
    });

    fallback = FALLBACK_QUESTIONS.what_if;
  } else {
    questionType = 'trap';

    prompt = buildTrapPrompt({
      submission: state.submission,
      rubric: state.rubric,
    });

    fallback = state.rubric.trap.question ||
      FALLBACK_QUESTIONS.trap;
  }

  const question = await generateQuestion(
    prompt,
    fallback
  );

  const questionRecord = {
    question,
    questionType,
    round: nextRound,
  };

  const updatedQuestions = [
    ...(state.questions ?? []),
    questionRecord,
  ];

  const updatedState = {
    ...state,

    turns: updatedTurns,

    round: nextRound,

    evaluations: updatedEvaluations,

    questions: updatedQuestions,
  };

  return {
    state: updatedState,

    question,

    questionType,

    round: nextRound,

    done: false,
  };
}


/**
 * Build the final report.
 */
export async function buildReport(state) {
  if (!state) {
    throw new Error('state is required');
  }

  const summary =
    state.summary ??
    buildSummary(state);

  return {
    session_id:
      state.sessionId ?? null,

    rubric_id:
      state.sampleId ?? null,

    score_before:
      summary.score_before,

    score_after:
      summary.score_after,

    bloom_reached:
      summary.bloom_reached,

    trap_caught:
      summary.trap_caught,

    trap_explanation:
      summary.trap_caught
        ? state.rubric.trap.answer
        : null,

    weakest_key_point:
      summary.weakest_key_point,

    key_points:
      summary.assessment,

    strengths:
      summary.strengths,

    gaps:
      summary.gaps,

    review_next:
      summary.review_next,

    paste_flags:
      summary.paste_flags,
  };
}