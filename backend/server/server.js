import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { z } from 'zod';
import { createSession, getSession, updateSession } from './store.js';
import { startSession, nextTurn, buildReport } from '../ai/index.js';

const app = express();
const PORT = process.env.PORT ?? 8000;

// Enable CORS for all origins for development
app.use(cors());
app.use(express.json());

// ── Schemas ───────────────────────────────────────────────────────────────────
const createSessionSchema = z.object({
  student_name: z.string(),
  title: z.string(),
  kind: z.enum(['code', 'text']),
  submission: z.string(),
  language: z.string().optional(),
  sample_id: z.string().optional()
});

const turnSchema = z.object({
  text: z.string(),
  pasted: z.boolean()
});

// ── Hardcoded Responses ───────────────────────────────────────────────────────
const TEACHER_SUMMARY_EXAMPLE = {
  "assignment": "Binary search",
  "sessions": [
    {
      "session_id": "s_a1b2",
      "student": "Jordan Lee",
      "score_before": 61,
      "score_after": 75,
      "bloom_reached": "Apply",
      "trap_caught": false,
      "weakest_key_point": "O(log n) time complexity",
      "sample": true,
      "finished_at": "2026-10-01T09:14:00Z"
    },
    {
      "session_id": "s_c3d4",
      "student": "Priya Sharma",
      "score_before": 45,
      "score_after": 68,
      "bloom_reached": "Understand",
      "trap_caught": false,
      "weakest_key_point": "Loop termination condition",
      "sample": true,
      "finished_at": "2026-10-01T10:02:00Z"
    },
    {
      "session_id": "s_e5f6",
      "student": "Marcus Webb",
      "score_before": 70,
      "score_after": 88,
      "bloom_reached": "Analyse",
      "trap_caught": true,
      "weakest_key_point": "Midpoint comparison for the equal case",
      "sample": true,
      "finished_at": "2026-10-02T08:45:00Z"
    },
    {
      "session_id": "s_g7h8",
      "student": "Sofia Reyes",
      "score_before": 50,
      "score_after": 63,
      "bloom_reached": "Understand",
      "trap_caught": false,
      "weakest_key_point": "Loop termination condition",
      "sample": true,
      "finished_at": "2026-10-02T14:30:00Z"
    },
    {
      "session_id": "s_i9j0",
      "student": "Tariq Osei",
      "score_before": 66,
      "score_after": 80,
      "bloom_reached": "Apply",
      "trap_caught": true,
      "weakest_key_point": "O(log n) time complexity",
      "sample": true,
      "finished_at": "2026-10-03T11:20:00Z"
    },
    {
      "session_id": "s_k3f9",
      "student": "Alice Nguyen",
      "score_before": 54,
      "score_after": 79,
      "bloom_reached": "Analyse",
      "trap_caught": true,
      "weakest_key_point": "Off-by-one and mid-point edge cases",
      "sample": false,
      "finished_at": "2026-10-04T17:55:00Z"
    }
  ],
  "weak_concepts": [
    { "concept": "Loop termination condition", "count": 2, "total": 6 },
    { "concept": "O(log n) time complexity", "count": 2, "total": 6 },
    { "concept": "Midpoint comparison for the equal case", "count": 1, "total": 6 }
  ]
};

// ── Routes ────────────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({ ok: true });
});

app.post('/sessions', async (req, res) => {
  try {
    const data = createSessionSchema.parse(req.body);
    const aiState = await startSession({
      submission: data.submission,
      kind: data.kind,
      language: data.language,
      sampleId: data.sample_id
    });
    
    const sessionId = createSession({
      student_name: data.student_name,
      title: data.title,
      kind: data.kind,
      sample_id: data.sample_id,
      aiState,
      paste_flags: 0,
      isDone: false,
      report: null
    });
    
    res.json({ session_id: sessionId });
  } catch (err) {
    if (err instanceof z.ZodError) {
      return res.status(400).json({ error: 'request body is invalid' });
    }
    console.error(err);
    res.status(502).json({ error: 'The duck is having trouble thinking. Please try again.' });
  }
});

app.post('/sessions/:id/turn', async (req, res) => {
  try {
    const data = turnSchema.parse(req.body);
    const session = getSession(req.params.id);
    if (!session) {
      return res.status(404).json({ error: 'session not found' });
    }
    
    const result = await nextTurn(session.aiState, data.text);
    
    updateSession(req.params.id, {
      aiState: result.state,
      isDone: result.done,
      paste_flags: session.paste_flags + (data.pasted ? 1 : 0)
    });
    
    res.json({
      question: result.question,
      question_type: result.questionType,
      round: result.round,
      done: result.done
    });
  } catch (err) {
    if (err instanceof z.ZodError) {
      return res.status(400).json({ error: 'request body is invalid' });
    }
    console.error(err);
    res.status(502).json({ error: 'The duck is having trouble thinking. Please try again.' });
  }
});

app.get('/sessions/:id/report', async (req, res) => {
  try {
    const session = getSession(req.params.id);
    if (!session) {
      return res.status(404).json({ error: 'session not found' });
    }
    if (!session.isDone) {
      return res.status(409).json({ error: 'viva is still in progress' });
    }
    
    if (!session.report) {
      // Pass the session ID into state so buildReport includes it correctly
      const finalState = { ...session.aiState, sessionId: req.params.id };
      const report = await buildReport(finalState);
      updateSession(req.params.id, { report });
      session.report = report;
    }
    
    res.json({
      ...session.report,
      paste_flags: session.paste_flags
    });
  } catch (err) {
    console.error(err);
    res.status(502).json({ error: 'The duck is having trouble thinking. Please try again.' });
  }
});

app.get('/teacher/summary', (req, res) => {
  res.json(TEACHER_SUMMARY_EXAMPLE);
});

// ── Start ─────────────────────────────────────────────────────────────────────
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server listening on http://0.0.0.0:${PORT}`);
});
