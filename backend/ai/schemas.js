import { z } from 'zod';

export const Rubric = z.object({
  key_points: z.array(
    z.object({
      id: z.string(),
      statement: z.string(),
    })
  ),
  trap: z.object({
    question: z.string(),
    answer: z.string(),
  }),
});

export const TurnResult = z.object({
  question: z.string(),
  question_type: z.enum(['probe', 'what_if', 'trap']),
  round: z.number(),
  done: z.boolean(),
});

export const ReportText = z.object({
  strengths: z.array(z.string()),
  gaps: z.array(z.string()),
  review_next: z.array(z.string()),
});

export const RubricSchema = Rubric;
export const TurnResultSchema = TurnResult;
export const ReportTextSchema = ReportText;
