// HTTP routes for every contract in shared/contracts/, plus the Flutter web
// build when PUBLIC_DIR exists (one service serves both).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import express from 'express';
import cors from 'cors';
import { z } from 'zod';

import { createEngine, AiError, AiNotConfigured } from '../ai/index.js';
import { rubrics as defaultRubrics, questionOf, rubricFromDraft } from '../ai/rubrics.js';
import { agreement, marksOf, verifyPoints } from '../ai/scoring.js';
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
const MAX_PDF_BYTES = 10 * 1024 * 1024;
/** One upload (photos or PDFs) for one answer or one answer sheet. */
const MAX_PAGES = 10;
const MAX_UPLOAD_BYTES = 15 * 1024 * 1024;
/** Questions on one answer sheet. */
const MAX_SHEET_QUESTIONS = 10;
const UPLOAD_PATHS = new Set(['/transcribe', '/teacher/sheets/read']);

const ERR = {
  invalid: 'request body is invalid',
  notFound: 'session not found',
  inProgress: 'viva is still in progress',
  duck: 'The duck is having trouble thinking. Please try again.',
  photo: 'Please upload a JPEG or PNG photo under 5 MB.',
  document: 'Please upload up to 10 JPEG or PNG pages (5 MB each) or a PDF (10 MB), under 15 MB in all.',
  notAQuestion:
    "That doesn't look like a question the duck can grade. Write a question that asks for an explanation in a few sentences or paragraphs.",
  noWriting: "We couldn't find any writing in that photo. Try again with the page filling the frame.",
  noAnswers: "We couldn't find answers to any of the chosen questions on that sheet. Check the questions and the pages, then try again.",
};

// ── Request bodies ───────────────────────────────────────────────────────────

const TranscriptionInfo = z.object({
  legibility: z.enum(['clear', 'unclear']),
  confidence: z.number().min(0).max(1),
  edited: z.boolean().default(false),
});
const CustomQuestion = z.object({
  prompt: z.string().trim().min(10).max(3000),
  subject: z.string().trim().max(60).nullish(),
});
const CreateSession = z.object({
  student_name: z.string().trim().min(1).max(100),
  question_id: z.string().nullish(),
  custom_question: CustomQuestion.nullish(),
  answer_text: z.string().trim().min(1).max(12000),
  source: z.enum(['typed', 'photo', 'document']).default('typed'),
  pasted: z.boolean().default(false),
  transcription: TranscriptionInfo.nullish(),
});
const DraftRequest = z.object({
  prompt: z.string().trim().min(10).max(3000),
  subject: z.string().trim().max(60).nullish(),
  marks: z.number().int().min(1).max(100).default(10),
  model_answer: z.string().trim().max(8000).nullish(),
});
/** The rubric as the teacher edits it; rubricFromDraft turns it into the stored shape. */
const QuestionDraft = z.object({
  title: z.string().trim().min(1).max(80),
  subject: z.string().trim().max(60).default(''),
  prompt: z.string().trim().min(10).max(3000),
  marks: z.number().int().min(1).max(100).default(10),
  points: z
    .array(
      z.object({
        statement: z.string().trim().min(3).max(400),
        weight: z.number().int().min(1).max(3),
        hint: z.string().trim().max(300).default(''),
        probe: z.string().trim().max(400).default(''),
      }),
    )
    .min(2)
    .max(10),
  trap: z.object({ false_claim: z.string().trim().min(5).max(400), truth: z.string().trim().min(5).max(500) }),
  what_if: z.string().trim().min(5).max(400),
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
const ProfileUpdate = z.object({ name: z.string().trim().min(1).max(100) });
const PasswordChange = z.object({ current_password: z.string().min(1), new_password: z.string().min(8).max(200) });
const TeacherScore = z.object({
  score: z.number().int().min(0).max(100),
  note: z.string().max(2000).nullish(),
});
const Upload = z.object({
  image_base64: z.string().min(1),
  mime_type: z.enum(['image/jpeg', 'image/png', 'application/pdf']),
});
/** One photo (image_base64 + mime_type), or several pages / a PDF (pages). */
const Transcribe = z.object({
  question_id: z.string().nullish(),
  image_base64: z.string().min(1).nullish(),
  mime_type: z.enum(['image/jpeg', 'image/png']).nullish(),
  pages: z.array(Upload).min(1).max(MAX_PAGES).nullish(),
});
const SheetRead = z.object({
  question_ids: z.array(z.string()).min(1).max(MAX_SHEET_QUESTIONS),
  pages: z.array(Upload).min(1).max(MAX_PAGES),
});
const SheetGrade = z.object({
  student_name: z.string().trim().min(1).max(100),
  answers: z
    .array(
      z.object({
        question_id: z.string(),
        text: z.string().trim().max(12000).default(''),
        transcription: TranscriptionInfo.nullish(),
      }),
    )
    .min(1)
    .max(MAX_SHEET_QUESTIONS),
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

/**
 * Decodes uploaded pages for the model, or null when one is empty, too big,
 * or they are too big together.
 */
function filesOf(pages) {
  let total = 0;
  const files = [];
  for (const p of pages) {
    const data = p.image_base64.replace(/^data:[^,]*,/, '');
    const n = Buffer.from(data, 'base64').length;
    const max = p.mime_type === 'application/pdf' ? MAX_PDF_BYTES : MAX_PHOTO_BYTES;
    if (n === 0 || n > max) return null;
    total += n;
    files.push({ data, mimeType: p.mime_type });
  }
  return total <= MAX_UPLOAD_BYTES ? files : null;
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
  app.use(express.json({ limit: '25mb' }));
  app.use(attachUser(store));
  const aiLimit = rateLimit({ perMinute: limits.aiPerMinute });

  const parse = (schema, body) => {
    const r = schema.safeParse(body ?? {});
    return r.success ? r.data : null;
  };

  /** A preset rubric, or one a teacher or student wrote (kept after deletion for old sessions). */
  const rubricOf = (id) => (id ? (rubrics.get(id) ?? store.question(id)?.rubric ?? null) : null);

  /** Questions students can pick: published teacher questions (newest first), then the presets. */
  function questionList() {
    const teacher = store
      .questions()
      .filter((q) => q.origin === 'teacher' && !q.archived)
      .sort((a, b) => b.created_at.localeCompare(a.created_at))
      .map((q) => ({ ...questionOf(q.rubric), origin: 'teacher', author: q.author_name ?? null }));
    const samples = [...rubrics.values()].map((r) => ({ ...questionOf(r), origin: 'sample', author: null }));
    return [...teacher, ...samples];
  }

  // In-flight work that must not run twice for one session.
  const busy = new Set();
  const finalising = new Map();

  function finalise(s) {
    if (s.report) return Promise.resolve(s.report);
    if (!finalising.has(s.id)) {
      const rubric = rubricOf(s.question_id);
      const job = engine
        // Older sessions have no trap of their own: they were asked the rubric's.
        .finalise(rubric, { answer: s.answer_text, replies: s.replies.map((r) => r.text), grade: s.grade, trap: s.trap ?? rubric.trap })
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
    const rubric = rubricOf(s.question_id);
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
      question_title: rubricOf(s.question_id)?.title ?? s.question_id,
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
    res.json({ questions: questionList() });
  });

  app.post('/questions/draft', requireTeacher, aiLimit, async (req, res) => {
    const b = parse(DraftRequest, req.body);
    if (!b) return res.status(400).json({ error: ERR.invalid });
    const draft = await engine.draftRubric({
      prompt: b.prompt,
      subject: b.subject ?? '',
      marks: b.marks,
      modelAnswer: b.model_answer ?? '',
    });
    if (!draft) return res.status(422).json({ error: ERR.notAQuestion });
    res.json({ draft });
  });

  app.post('/questions', requireTeacher, (req, res) => {
    const b = parse(QuestionDraft, req.body);
    if (!b) return res.status(400).json({ error: ERR.invalid });
    const id = newId('q', 4);
    const q = store.putQuestion({
      id,
      origin: 'teacher',
      author_id: req.user.id,
      author_name: req.user.name,
      archived: false,
      created_at: new Date().toISOString(),
      rubric: rubricFromDraft(id, b),
    });
    res.status(201).json({ question: { ...questionOf(q.rubric), origin: 'teacher', author: q.author_name } });
  });

  app.delete('/questions/:id', requireTeacher, (req, res) => {
    const q = store.question(req.params.id);
    if (!q || q.origin !== 'teacher' || q.archived) return res.status(404).json({ error: 'question not found' });
    q.archived = true;
    store.putQuestion(q);
    res.json({ ok: true });
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

  // ── Profile (contract 11) ──────────────────────────────────────────────────

  const DEMO_IDS = new Set(DEMO_ACCOUNTS.map((a) => a.id));
  /** Demo logins are shared with judges, so nobody can lock the others out. */
  function editableUser(req, res) {
    if (!req.user) {
      res.status(401).json({ error: 'Please sign in first.' });
      return null;
    }
    if (DEMO_IDS.has(req.user.id)) {
      res.status(403).json({ error: "Demo accounts are shared, so their name and password can't be changed." });
      return null;
    }
    return req.user;
  }

  app.get('/auth/me', (req, res) => {
    if (!req.user) return res.status(401).json({ error: 'Please sign in first.' });
    res.json({ user: publicUser(req.user) });
  });

  app.patch('/auth/me', (req, res) => {
    const b = parse(ProfileUpdate, req.body);
    if (!b) return res.status(400).json({ error: 'Please enter your name.' });
    const user = editableUser(req, res);
    if (!user) return;
    user.name = b.name;
    store.save();
    res.json({ user: publicUser(user) });
  });

  app.post('/auth/password', (req, res) => {
    const b = parse(PasswordChange, req.body);
    if (!b) return res.status(400).json({ error: 'The new password needs at least 8 characters.' });
    const user = editableUser(req, res);
    if (!user) return;
    if (!checkPassword(b.current_password, user.password)) {
      return res.status(401).json({ error: "Your current password isn't right." });
    }
    user.password = hashPassword(b.new_password);
    // Other devices signed in with the old password are signed out.
    const token = /^Bearer\s+(.+)$/i.exec(req.get('authorization') ?? '')[1].trim();
    store.dropTokens(user.id, token);
    res.json({ ok: true });
  });

  // ── Transcription ──────────────────────────────────────────────────────────

  app.post('/transcribe', aiLimit, async (req, res) => {
    const b = parse(Transcribe, req.body);
    const pages = b?.pages ?? (b?.image_base64 && b.mime_type ? [{ image_base64: b.image_base64, mime_type: b.mime_type }] : null);
    const files = pages && filesOf(pages);
    if (!files) return res.status(400).json({ error: b?.pages || req.body?.pages ? ERR.document : ERR.photo });
    const result = await engine.transcribe(rubricOf(b.question_id), files);
    if (!result) return res.status(422).json({ error: ERR.noWriting });
    res.json(result);
  });

  // ── Viva ───────────────────────────────────────────────────────────────────

  app.post('/sessions', aiLimit, async (req, res) => {
    const b = parse(CreateSession, req.body);
    if (!b || !!b.question_id === !!b.custom_question) return res.status(400).json({ error: ERR.invalid });
    let rubric = rubricOf(b.question_id);
    if (b.custom_question) {
      // The student's own question: draft a rubric for it, and keep it so the
      // report and the teacher can see exactly what it was graded against.
      const draft = await engine.draftRubric({ prompt: b.custom_question.prompt, subject: b.custom_question.subject ?? '' });
      if (!draft) return res.status(422).json({ error: ERR.notAQuestion });
      const id = newId('q', 4);
      rubric = store.putQuestion({
        id,
        origin: 'student',
        author_id: req.user?.id ?? null,
        author_name: b.student_name,
        created_at: new Date().toISOString(),
        rubric: rubricFromDraft(id, draft),
      }).rubric;
    }
    if (!rubric) return res.status(400).json({ error: ERR.invalid });
    const grade = await engine.gradeAnswer(rubric, b.answer_text, {
      pasted: b.pasted,
      transcription: b.source === 'typed' ? null : b.transcription,
      aiRubric: !!b.custom_question,
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
    res.status(201).json({ session_id: s.id, grade, question, question_type: 'probe', round: 0, question_info: questionOf(rubric) });
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
      const rubric = rubricOf(s.question_id);
      const replies = [...s.replies, { text: b.text, pasted: b.pasted }];
      const round = replies.length;
      let next = null;
      if (round === 1) next = { type: 'what_if', text: await engine.whatIfQuestion(rubric, [s.answer_text, b.text]) };
      if (round === 2) {
        const trap = await engine.trapQuestion(rubric, [s.answer_text, ...replies.map((r) => r.text)]);
        s.trap = { false_claim: trap.false_claim, truth: trap.truth, source: trap.source };
        next = { type: 'trap', text: trap.text };
      }
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

  // ── Answer sheets (contract 10) ────────────────────────────────────────────

  /** The rubrics for [ids], or null when one is unknown or repeated. */
  function sheetRubrics(ids) {
    if (new Set(ids).size !== ids.length) return null;
    const list = ids.map(rubricOf);
    return list.every(Boolean) ? list : null;
  }

  function sheetSummary(sh) {
    return {
      sheet_id: sh.id,
      student: sh.student_name,
      graded_by: sh.teacher_name,
      total_marks: sh.total_marks,
      max_marks: sh.max_marks,
      questions: sh.questions.length,
      answered: sh.questions.filter((q) => q.answered).length,
      needs_review: sh.needs_review,
      created_at: sh.created_at,
    };
  }

  app.post('/teacher/sheets/read', requireTeacher, aiLimit, async (req, res) => {
    const b = parse(SheetRead, req.body);
    const rubricList = b && sheetRubrics(b.question_ids);
    if (!rubricList) return res.status(400).json({ error: b ? ERR.invalid : ERR.document });
    const files = filesOf(b.pages);
    if (!files) return res.status(400).json({ error: ERR.document });
    const answers = await engine.readSheet(rubricList, files);
    if (!answers) return res.status(422).json({ error: ERR.noAnswers });
    res.json({ answers });
  });

  app.post('/teacher/sheets', requireTeacher, aiLimit, async (req, res) => {
    const b = parse(SheetGrade, req.body);
    const rubricList = b && sheetRubrics(b.answers.map((a) => a.question_id));
    if (!rubricList) return res.status(400).json({ error: ERR.invalid });
    const questions = [];
    // One question at a time: each is two model calls, and the free tier
    // allows only a few calls at once.
    for (const [i, a] of b.answers.entries()) {
      const rubric = rubricList[i];
      const max = rubric.marks ?? 10;
      let grade;
      if (a.text) {
        grade = await engine.gradeAnswer(rubric, a.text, { transcription: a.transcription ?? null });
      } else {
        const points = verifyPoints(rubric, [], []).points.map((p) => ({ ...p, comment: 'No answer to this question was found on the sheet.' }));
        grade = { score: 0, runs: [0, 0], points, review: { needs_review: false, reasons: [] } };
      }
      questions.push({
        question_id: rubric.id,
        title: rubric.title,
        prompt: rubric.prompt,
        answered: !!a.text,
        answer_text: a.text,
        transcription: a.transcription ?? null,
        score: grade.score,
        marks: marksOf(grade.score, max),
        max_marks: max,
        grade,
      });
    }
    const sh = store.putSheet({
      id: newId('sh'),
      student_name: b.student_name,
      teacher_id: req.user.id,
      teacher_name: req.user.name,
      created_at: new Date().toISOString(),
      total_marks: questions.reduce((t, q) => t + q.marks, 0),
      max_marks: questions.reduce((t, q) => t + q.max_marks, 0),
      needs_review: questions.some((q) => q.grade.review.needs_review),
      questions,
    });
    res.status(201).json({ ...sheetSummary(sh), items: sh.questions });
  });

  app.get('/teacher/sheets', requireTeacher, (_req, res) => {
    const sheets = store
      .sheets()
      .sort((a, b) => b.created_at.localeCompare(a.created_at))
      .map(sheetSummary);
    res.json({ sheets });
  });

  app.get('/teacher/sheets/:id', requireTeacher, (req, res) => {
    const sh = store.sheet(req.params.id);
    if (!sh) return res.status(404).json({ error: 'answer sheet not found' });
    res.json({ ...sheetSummary(sh), items: sh.questions });
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
      return UPLOAD_PATHS.has(req.path) ? res.status(400).json({ error: ERR.document }) : res.status(413).json({ error: ERR.invalid });
    }
    console.error(err);
    res.status(500).json({ error: 'Something went wrong on our side. Please try again.' });
  });

  return app;
}
