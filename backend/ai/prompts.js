export const RUBRIC_PROMPT = `
You are an expert viva examiner.

Given a student's assignment or code, create a concise assessment rubric.

Return ONLY JSON matching this structure:
{
  "key_points": [
    {
      "id": "kp1",
      "statement": "important concept the student should understand"
    }
  ],
  "trap": {
    "question": "a believable but misleading viva question",
    "answer": "the correct explanation of why the trap is misleading"
  }
}

Rules:
- Create 4 to 6 important key points.
- Key points must test actual understanding, not memorization.
- The trap question must be false but believable.
- The trap should test an edge case, hidden assumption, limitation, or common misconception.
- Keep questions relevant to the student's submission.
`;

export const PROBE_PROMPT = `
Ask one probe question that checks whether the student genuinely understands how their submitted code or assignment works.

The question should make the student explain reasoning, execution flow, or an important concept.

Return ONLY the question text.
`;

export const WHAT_IF_PROMPT = `
Ask one "what if" question that changes an important assumption of the student's submission.

The question should test whether the student understands limitations, edge cases, or consequences of changing an input or condition.

Return ONLY the question text.
`;

export const TRAP_PROMPT = `
Ask one believable trap question based on the student's submission.

The question should contain a subtle misconception or hidden assumption that a student who only memorized the code may miss.

The trap must have a clear technically correct explanation.

Return ONLY the question text.
`;

export function buildRubricPrompt({ submission, language, kind }) {
  return `${RUBRIC_PROMPT}

Language: ${language}
Assignment type: ${kind}

Student submission:
${submission}`;
}

export function buildProbePrompt({ submission, rubric }) {
  return `${PROBE_PROMPT}

Student submission:
${submission}

Rubric:
${JSON.stringify(rubric)}`;
}

export function buildWhatIfPrompt({ submission, rubric }) {
  return `${WHAT_IF_PROMPT}

Student submission:
${submission}

Rubric:
${JSON.stringify(rubric)}`;
}

export function buildTrapPrompt({ submission, rubric }) {
  return `${TRAP_PROMPT}

Student submission:
${submission}

Rubric:
${JSON.stringify(rubric)}`;
}
