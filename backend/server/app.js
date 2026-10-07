// HTTP routes for every contract in shared/contracts/, plus the Flutter web
// build when PUBLIC_DIR exists (one service serves both).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import express from 'express';
import cors from 'cors';
import { z } from 'zod';

import { createEngine, AiError, AiNotConfigured } from '../ai/index.js';
import { rubrics as defaultRubrics, questionOf } from '../ai/rubrics.js';
import { agreement } from '../ai/scoring.js';
import { Store } from './store.js';
import {
  attachUser,
  requireTeacher,
  hashPassword,
  checkPassword,
  newId,
  newToken,
  publicUser,
  DEMO_ACCOUNTS,
  DEMO_PASSWORD,
} from './auth.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const SAMPLES_FILE = path.resolve(here, '../../shared/contracts/04_teacher_summary.json');
const DEFAULT_PUBLIC_DIR = path.resolve(here, '../../app/build/web');

const FOLLOW_UPS = 3;
const MAX_PHOTO_BYTES = 5 * 1024 * 1024;

const ERR = {
  invalid: 'request body is invalid',
  notFound: 'session not found',
  inProgress: 'viva is still in progress',
  duck: 'The duck is having trouble thinking. Please try again.',
  photo: 'Please upload a JPEG or PNG photo under 5 MB.',
  noWriting: "We couldn't find any writing in that photo. Try again with the page filling the frame.",
};

// ── Request bodies ───────────────────────────────────────────────────────────

const CreateSession = z.object({
  student_name: z.string().trim().min(1).max(100),
  question_id: z.string(),
  answer_text: z.string().trim().min(1).max(12000),
  source: z.enum(['typed', 'photo']).default('typed'),
  pasted: z.boolean().default(false),
  transcription: z
    .object({
      legibility: z.enum(['clear', 'unclear']),
      confidence: z.number().min(0).max(1),
      edited: z.boolean().default(false),
    })
    .nullish(),
});
const Turn = z.object({ text: z.string().trim().min(1).max(6000), pasted: z.boolean().default(false) });
const Register = z.object({
  name: z.string().trim().min(1).max(100),
  email: z.string().trim().email(),
  password: z.string().min(8).max(200),
  role: z.enum(['student', 'teacher']),
  invite_code: z.string().trim().max(200).nullish(),
});
const Login = z.object({ email: z.string().trim().min(1), password: z.string().min(1) });
const TeacherScore = z.object({
  score: z.number().int().min(0).max(100),
  note: z.string().max(2000).nullish(),
});
const Transcribe = z.object({
  question_id: z.string().nullish(),
  image_base64: z.string().min(1),
  mime_type: z.enum(['image/jpeg', 'image/png']),
});

// ── Small helpers ────────────────────────────────────────────────────────────

/** Fixed-window limit per IP, to keep a public demo from burning the AI quota. */
function rateLimit({ perMinute }) {
  const hits = new Map();
  return (req, res, next) => {
    const now = Date.now();
    const key = req.ip;
    const h = hits.get(key);
    if (!h || now - h.start > 60_000) {
      hits.set(key, { start: now, n: 1 });
      if (hits.size > 5000) hits.clear();
      return next();
    }
    if (++h.n > perMinute) return res.status(429).json({ error: 'Too many requests. Please wait a minute and try again.' });
    next();
  };
}

function seedSamples(store) {
  if (store.data.seeded || !fs.existsSync(SAMPLES_FILE)) return;
  const rows = JSON.parse(fs.readFileSync(SAMPLES_FILE, 'utf8')).response.sessions;
  for (const row of rows) {
    const { teacher_score, ...summary } = row;
    store.putSession({ id: row.session_id, sample: true, done: true, row: summary, teacher_score });
  }
  store.data.seeded = true;
  store.save();
}

function seedDemoAccounts(store) {
  for (const a of DEMO_ACCOUNTS) {
    if (!store.userByEmail(a.email)) store.addUser({ ...a, password: hashPassword(DEMO_PASSWORD) });
  }
}

// ── App ──────────────────────────────────────────────────────────────────────

export function createApp({
  engine = createEngine(),
  store = new Store(process.env.DATA_DIR || null),
  rubrics = defaultRubrics,
  publicDir = process.env.PUBLIC_DIR ?? DEFAULT_PUBLIC_DIR,
  seed = { samples: process.env.SEED_SAMPLES === 'true', demoAccounts: process.env.SEED_DEMO_ACCOUNTS === 'true' },
  limits = { aiPerMinute: Number(process.env.AI_RATE_PER_MINUTE ?? 40) },
  teacherInviteCode = process.env.TEACHER_INVITE_CODE || null,
} = {}) {
  if (seed.samples) seedSamples(store);
  if (seed.demoAccounts) seedDemoAccounts(store);

  const app = express();
  app.set('trust proxy', 1);
  app.disable('x-powered-by');
  app.use(cors());
  app.use(express.json({ limit: '8mb' }));
  app.use(attachUser(store));
  const aiLimit = rateLimit({ perMinute: limits.aiPerMinute });

  const parse = (schema, body) => {
    const r = schema.safeParse(body ?? {});
    return r.success ? r.data : null;
  };

  // In-flight work that must not run twice for one session.
  const busy = new Set();
  const finalising = new Map();

  function finalise(s) {
    if (s.report) return Promise.resolve(s.report);
    if (!finalising.has(s.id)) {
      const rubric = rubrics.get(s.question_id);
      const job = engine
        .finalise(rubric, { answer: s.answer_text, replies: s.replies.map((r) => r.text), grade: s.grade })
        .then((result) => {
          s.report = result;
          store.putSession(s);
          return result;
        })
        .finally(() => finalising.delete(s.id));
      finalising.set(s.id, job);
    }
    return finalising.get(s.id);
  }

  function reportOf(s) {
    const rubric = rubrics.get(s.question_id);
    return {
      session_id: s.id,
      question_id: s.question_id,
      title: rubric.title,
      question_prompt: rubric.prompt,
      answer_text: s.answer_text,
      source: s.source,
      score_before: s.grade.score,
      score_after: s.report.score_after,
      grading_runs: s.grade.runs,
      review: s.grade.review,
      bloom_reached: s.report.bloom_reached,
      trap_caught: s.report.trap_caught,
      trap_explanation: s.report.trap_explanation,
      weakest_key_point: s.report.weakest_key_point,
      key_points: s.report.key_points,
      strengths: s.report.strengths,
      gaps: s.report.gaps,
      review_next: s.report.review_next,
      paste_flags: s.paste_flags,
    };
  }

  function summaryRow(s) {
    if (s.sample) return { ...s.row, teacher_score: s.teacher_score ?? null, sample: true };
    return {
      session_id: s.id,
      student: s.student_name,
      question_id: s.question_id,
      question_title: rubrics.get(s.question_id)?.title ?? s.question_id,
      score_before: s.grade.score,
      score_after: s.report.score_after,
      bloom_reached: s.report.bloom_reached,
      trap_caught: s.report.trap_caught,
      weakest_key_point: s.report.weakest_key_point,
      source: s.source,
      needs_review: s.grade.review.needs_review,
      review_reasons: s.grade.review.reasons,
      teacher_score: s.teacher_score ?? null,
      sample: false,
      finished_at: s.finished_at,
    };
  }

  function classRows() {
    const rows = [];
    for (const s of store.sessions()) {
      if (!s.done) continue;
      if (!s.sample && !s.report) {
        finalise(s).catch(() => {});
        continue;
      }
      rows.push(summaryRow(s));
    }
    return rows.sort((a, b) => b.finished_at.localeCompare(a.finished_at));
  }

  // ── Health & questions ─────────────────────────────────────────────────────

  app.get('/health', (_req, res) => {
    res.json({ ok: true, ai: engine.mode, model: engine.model });
  });

  app.get('/questions', (_req, res) => {
    res.json({ questions: [...rubrics.values()].map(questionOf) });
  });

  // ── Auth ───────────────────────────────────────────────────────────────────

  app.post('/auth/register', (req, res) => {
    const b = parse(Register, req.body);
    if (!b) return res.status(400).json({ error: ERR.invalid });
    if (b.role === 'teacher' && teacherInviteCode && b.invite_code !== teacherInviteCode) {
      return res.status(403).json({
        error: b.invite_code ? "That teacher invite code isn't right." : 'Teacher accounts need an invite code from your school admin.',
      });
    }
    if (store.userByEmail(b.email)) {
      return res.status(409).json({ error: 'An account with this email already exists.' });
    }
    const user = store.addUser({
      id: newId('u', 4),
      name: b.name,
      email: b.email.toLowerCase(),
      role: b.role,
      password: hashPassword(b.password),
    });
    const token = newToken();
    store.addToken(token, user.id);
    res.status(201).json({ token, user: publicUser(user) });
  });

  app.post('/auth/login', (req, res) => {
    const b = parse(Login, req.body);
    if (!b) return res.status(400).json({ error: ERR.invalid });
    const user = store.userByEmail(b.email);
    if (!user || !checkPassword(b.password, user.password)) {
      return res.status(401).json({ error: "That email and password don't match." });
    }
    const token = newToken();
    store.addToken(token, user.id);
    res.json({ token, user: publicUser(user) });
  });

  // ── Transcription ──────────────────────────────────────────────────────────

  app.post('/transcribe', aiLimit, async (req, res) => {
    const b = parse(Transcribe, req.body);
    if (!b) return res.status(400).json({ error: ERR.photo });
    const data = b.image_base64.replace(/^data:[^,]*,/, '');
    const bytes = Buffer.from(data, 'base64');
    if (bytes.length === 0 || bytes.length > MAX_PHOTO_BYTES) return res.status(400).json({ error: ERR.photo });
    const result = await engine.transcribe(rubrics.get(b.question_id ?? '') ?? null, { data, mimeType: b.mime_type });
    if (!result) return res.status(422).json({ error: ERR.noWriting });
    res.json(result);
  });

  // ── Viva ───────────────────────────────────────────────────────────────────

  app.post('/sessions', aiLimit, async (req, res) => {
    const b = parse(CreateSession, req.body);
    const rubric = b && rubrics.get(b.question_id);
    if (!rubric) return res.status(400).json({ error: ERR.invalid });
    const grade = await engine.gradeAnswer(rubric, b.answer_text, {
      pasted: b.pasted,
      transcription: b.source === 'photo' ? b.transcription : null,
    });
    const question = await engine.probeQuestion(rubric, b.answer_text, grade);
    const s = store.putSession({
      id: newId('s'),
      user_id: req.user?.id ?? null,
      student_name: b.student_name,
      question_id: rubric.id,
      answer_text: b.answer_text,
      source: b.source,
      pasted: b.pasted,
      transcription: b.transcription ?? null,
      grade,
      questions: [{ type: 'probe', text: question }],
      replies: [],
      paste_flags: b.pasted ? 1 : 0,
      done: false,
      created_at: new Date().toISOString(),
      finished_at: null,
      report: null,
      teacher_score: null,
      teacher_note: null,
    });
    res.status(201).json({ session_id: s.id, grade, question, question_type: 'probe', round: 0 });
  });

  app.post('/sessions/:id/turn', aiLimit, async (req, res) => {
    const b = parse(Turn, req.body);
    if (!b) return res.status(400).json({ error: ERR.invalid });
    const s = store.session(req.params.id);
    if (!s || s.sample) return res.status(404).json({ error: ERR.notFound });
    if (s.done) return res.status(409).json({ error: 'This viva is already finished.' });
    if (busy.has(s.id)) return res.status(409).json({ error: 'The duck is still thinking about your last answer.' });
    busy.add(s.id);
    try {
      const rubric = rubrics.get(s.question_id);
      const replies = [...s.replies, { text: b.text, pasted: b.pasted }];
      const round = replies.length;
      let next = null;
      if (round === 1) next = { type: 'what_if', text: await engine.whatIfQuestion(rubric, [s.answer_text, b.text]) };
      if (round === 2) next = { type: 'trap', text: engine.trapQuestion(rubric) };
      s.replies = replies;
      if (b.pasted) s.paste_flags += 1;
      if (next) s.questions.push(next);
      if (round >= FOLLOW_UPS) {
        s.done = true;
        s.finished_at = new Date().toISOString();
      }
      store.putSession(s);
      if (s.done) finalise(s).catch(() => {}); // report is ready by the time the app asks
      res.json({ question: next?.text ?? null, question_type: next?.type ?? null, round, done: s.done });
    } finally {
      busy.delete(s.id);
    }
  });

  app.get('/sessions/:id/report', async (req, res) => {
    const s = store.session(req.params.id);
    if (!s || s.sample) return res.status(404).json({ error: ERR.notFound });
    if (!s.done) return res.status(409).json({ error: ERR.inProgress });
    await finalise(s);
    res.json(reportOf(s));
  });

  // ── Teacher ────────────────────────────────────────────────────────────────

  app.get('/teacher/summary', requireTeacher, (_req, res) => {
    const sessions = classRows();
    const counts = new Map();
    for (const r of sessions) {
      if (!r.weakest_key_point || r.weakest_key_point === 'None') continue;
      counts.set(r.weakest_key_point, (counts.get(r.weakest_key_point) ?? 0) + 1);
    }
    const weak_concepts = [...counts.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 4)
      .map(([concept, count]) => ({ concept, count, total: sessions.length }));
    res.json({ assignment: 'All questions', sessions, agreement: agreement(sessions), weak_concepts });
  });

  app.post('/sessions/:id/teacher_score', requireTeacher, (req, res) => {
    const b = parse(TeacherScore, req.body);
    if (!b) return res.status(400).json({ error: 'Score must be a whole number from 0 to 100.' });
    const s = store.session(req.params.id);
    if (!s || !s.done) return res.status(404).json({ error: ERR.notFound });
    s.teacher_score = b.score;
    s.teacher_note = b.note ?? null;
    store.putSession(s);
    res.json({ session_id: s.id, teacher_score: b.score, agreement: agreement(classRows()) });
  });

  // ── Web app ────────────────────────────────────────────────────────────────

  if (publicDir && fs.existsSync(path.join(publicDir, 'index.html'))) {
    const noCache = /(index\.html|flutter_bootstrap\.js|flutter_service_worker\.js|version\.json|manifest\.json)$/;
    app.use(
      express.static(publicDir, {
        setHeaders: (res, file) => {
          if (noCache.test(file)) res.setHeader('Cache-Control', 'no-cache');
        },
      }),
    );
    app.use((req, res, next) => {
      if (req.method !== 'GET' || !req.accepts('html')) return next();
      res.setHeader('Cache-Control', 'no-cache');
      res.sendFile(path.join(publicDir, 'index.html'));
    });
  }

  // ── Errors ─────────────────────────────────────────────────────────────────

  app.use((_req, res) => res.status(404).json({ error: 'not found' }));

  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, _next) => {
    if (err instanceof AiError) return res.status(502).json({ error: ERR.duck });
    if (err instanceof AiNotConfigured) {
      return res.status(503).json({ error: 'Grading is not set up on this server yet. Ask the admin to add a Gemini API key.' });
    }
    if (err?.type === 'entity.parse.failed') return res.status(400).json({ error: ERR.invalid });
    if (err?.type === 'entity.too.large') {
      return res.status(req.path === '/transcribe' ? 400 : 413).json({ error: req.path === '/transcribe' ? ERR.photo : ERR.invalid });
    }
    console.error(err);
    res.status(500).json({ error: 'Something went wrong on our side. Please try again.' });
  });

  return app;
}
