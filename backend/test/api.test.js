import { test } from 'node:test';
import assert from 'node:assert/strict';

import { boot, ANSWER } from './helpers.js';
import { AiError } from '../ai/llm.js';
import { rubrics } from '../ai/rubrics.js';

async function login(call, email) {
  const r = await call('POST', '/auth/login', { email, password: 'quack-quack-1' });
  assert.equal(r.status, 200);
  return r.body.token;
}

test('full viva with the offline grader follows contracts 00-04 and 08', async () => {
  const { call, close } = await boot();
  try {
    const q = await call('GET', '/questions');
    assert.deepEqual(q.body.questions.map((x) => x.id), ['binary_search', 'factorial_recursive', 'normalisation']);
    assert.equal(q.body.questions[0].points, 6);
    assert.equal(q.body.questions[0].trap, undefined, 'rubric internals stay on the server');

    const created = await call('POST', '/sessions', {
      student_name: 'Alice Nguyen', question_id: 'binary_search', answer_text: ANSWER, source: 'typed', pasted: false, transcription: null,
    });
    assert.equal(created.status, 201);
    const { session_id, grade, question_type, round } = created.body;
    assert.equal(question_type, 'probe');
    assert.equal(round, 0);
    assert.equal(grade.runs.length, 2);
    assert.equal(grade.score, Math.round((grade.runs[0] + grade.runs[1]) / 2));
    for (const p of grade.points) {
      if (p.status !== 'missing') assert.ok(ANSWER.includes(p.evidence_quote), `quote for ${p.id} is verbatim`);
    }

    assert.equal((await call('GET', `/sessions/${session_id}/report`)).status, 409);

    const t1 = await call('POST', `/sessions/${session_id}/turn`, { text: 'If it is not sorted, discarding half could throw away the target.', pasted: false });
    assert.deepEqual([t1.body.question_type, t1.body.round, t1.body.done], ['what_if', 1, false]);
    const t2 = await call('POST', `/sessions/${session_id}/turn`, { text: 'It finds one of them, not necessarily the first one, unless you keep searching left.', pasted: true });
    assert.equal(t2.body.question_type, 'trap');
    assert.match(t2.body.question, /classmate/);
    const t3 = await call('POST', `/sessions/${session_id}/turn`, { text: "No, that's wrong. Without order one comparison can't rule out half the list.", pasted: false });
    assert.deepEqual([t3.body.question, t3.body.question_type, t3.body.round, t3.body.done], [null, null, 3, true]);
    assert.equal((await call('POST', `/sessions/${session_id}/turn`, { text: 'again' })).status, 409);

    const report = (await call('GET', `/sessions/${session_id}/report`)).body;
    assert.equal(report.score_before, grade.score);
    assert.ok(report.score_after >= report.score_before);
    assert.equal(report.trap_caught, true);
    assert.equal(report.paste_flags, 1);
    assert.equal(report.key_points.length, 6);

    // Teacher dashboard
    assert.equal((await call('GET', '/teacher/summary')).status, 401);
    const student = await login(call, 'student@vivduck.test');
    assert.equal((await call('GET', '/teacher/summary', undefined, student)).status, 403);
    const teacher = await login(call, 'teacher@vivduck.test');
    const summary = (await call('GET', '/teacher/summary', undefined, teacher)).body;
    assert.equal(summary.sessions[0].session_id, session_id, 'newest first');
    assert.equal(summary.sessions.length, 15);
    assert.equal(summary.agreement.sample_size, 11);

    const scored = await call('POST', `/sessions/${session_id}/teacher_score`, { score: 70, note: 'Fair.' }, teacher);
    assert.equal(scored.status, 200);
    assert.equal(scored.body.agreement.sample_size, 12);
    assert.equal((await call('POST', `/sessions/${session_id}/teacher_score`, { score: 101 }, teacher)).status, 400);
    assert.equal((await call('POST', '/sessions/nope/teacher_score', { score: 50 }, teacher)).status, 404);
  } finally {
    await close();
  }
});

test('bad input and unknown sessions', async () => {
  const { call, close } = await boot();
  try {
    assert.equal((await call('POST', '/sessions', { student_name: 'A', question_id: 'nope', answer_text: 'x' })).status, 400);
    assert.equal((await call('POST', '/sessions', { student_name: '', question_id: 'binary_search', answer_text: 'x' })).status, 400);
    assert.equal((await call('POST', '/sessions/s_none/turn', { text: 'hi' })).status, 404);
    assert.equal((await call('GET', '/sessions/s_none/report')).status, 404);
  } finally {
    await close();
  }
});

test('register, duplicate email and wrong password', async () => {
  const { call, close } = await boot();
  try {
    const body = { name: 'Bo', email: 'Bo@Example.com', password: 'longenough', role: 'teacher' };
    const r = await call('POST', '/auth/register', body);
    assert.equal(r.status, 201);
    assert.deepEqual(Object.keys(r.body.user).sort(), ['email', 'id', 'name', 'role']);
    assert.equal((await call('POST', '/auth/register', { ...body, email: 'bo@example.com' })).status, 409);
    assert.equal((await call('POST', '/auth/register', { ...body, email: 'x@y.z', password: 'short' })).status, 400);
    assert.equal((await call('POST', '/auth/login', { email: 'bo@example.com', password: 'wrong-one' })).status, 401);
    assert.equal((await call('POST', '/auth/login', { email: 'bo@example.com', password: 'longenough' })).status, 200);
  } finally {
    await close();
  }
});

test('model labels go through the evidence check and double grading', async () => {
  let gradingCalls = 0;
  const llm = async ({ prompt }) => {
    if (prompt.includes('deliberately FALSE')) {
      return { points: [], trap_caught: false, trap_explanation: 'The student agreed with the claim.', bloom_reached: 'Apply' };
    }
    if (prompt.includes('For EVERY rubric point')) {
      gradingCalls++;
      const strict = gradingCalls % 2 === 0;
      return {
        points: [
          { id: 'kp1', status: 'solid', evidence_quote: 'Binary search only works on a sorted list.', comment: 'Says it, not why.' },
          // Invented quote: must be rejected by the code, not trusted.
          { id: 'kp2', status: 'solid', evidence_quote: 'It always compares with the midpoint index.', comment: 'Good.' },
          { id: 'kp5', status: strict ? 'missing' : 'solid', evidence_quote: strict ? '' : 'so it takes about log n steps', comment: '' },
          { id: 'kp4', status: strict ? 'missing' : 'partial', evidence_quote: strict ? '' : 'It keeps halving until it finds the value or there is nothing left', comment: '' },
        ],
      };
    }
    return { question: 'Why does order matter here?' };
  };
  const { call, close } = await boot({ llm });
  try {
    const r = await call('POST', '/sessions', { student_name: 'Al', question_id: 'binary_search', answer_text: ANSWER });
    assert.equal(r.status, 201);
    const { grade, question } = r.body;
    assert.equal(question, 'Why does order matter here?');
    const kp2 = grade.points.find((p) => p.id === 'kp2');
    assert.equal(kp2.status, 'missing');
    assert.equal(kp2.evidence_quote, null);
    assert.ok(grade.review.reasons.some((x) => x.code === 'evidence_check'));
    // run 1: kp1 3 + kp5 2 + kp4 1 = 6/13 → 46; run 2: kp1 3/13 → 23
    assert.deepEqual(grade.runs, [46, 23]);
    assert.equal(grade.score, 35);
    assert.ok(grade.review.reasons.some((x) => x.code === 'runs_differ'));

    const id = r.body.session_id;
    for (const text of ['one', 'two', 'yes I agree']) await call('POST', `/sessions/${id}/turn`, { text });
    const report = (await call('GET', `/sessions/${id}/report`)).body;
    assert.equal(report.trap_caught, false);
    assert.equal(report.bloom_reached, 'Apply');
  } finally {
    await close();
  }
});

test('the trap is written by the model for each viva, and only a claim that is really false is used', async () => {
  /** claims: what the model writes, in turn; verdicts: the fact-checker's answers, in turn. */
  const fakeModel = ({ claims, verdicts, judged }) => async ({ prompt }) => {
    if (prompt.includes('deliberately FALSE')) {
      judged.push(prompt);
      return { points: [], trap_caught: true, trap_explanation: 'The student rejected it.', bloom_reached: 'Analyse' };
    }
    if (prompt.includes('For EVERY rubric point')) return { points: [] };
    if (prompt.includes('Write ONE false claim')) {
      const claim = claims.shift();
      if (claim === 'down') throw new AiError('model busy');
      return { false_claim: claim, truth: `Why "${claim}" is false.` };
    }
    if (prompt.includes('Fact-check this claim')) return { definitely_false: verdicts.shift(), reason: 'checked' };
    return { question: 'Next?' };
  };
  const viva = async (model) => {
    const { call, close } = await boot({ llm: model, seed: { samples: false, demoAccounts: false } });
    try {
      const id = (await call('POST', '/sessions', { student_name: 'Al', question_id: 'binary_search', answer_text: ANSWER })).body.session_id;
      await call('POST', `/sessions/${id}/turn`, { text: 'one' });
      const t2 = (await call('POST', `/sessions/${id}/turn`, { text: 'two' })).body;
      await call('POST', `/sessions/${id}/turn`, { text: 'No, that is wrong.' });
      await call('GET', `/sessions/${id}/report`);
      return t2.question;
    } finally {
      await close();
    }
  };

  // The first claim passes the check: asked, and judged against that claim.
  let judged = [];
  let q = await viva(fakeModel({ claims: ['Binary search needs the list to be stored in an array of even length.'], verdicts: [true], judged }));
  assert.equal(q, 'A classmate told me: “Binary search needs the list to be stored in an array of even length.” Do you agree?');
  assert.match(judged[0], /array of even length/);
  assert.match(judged[0], /Why "Binary search needs the list/);

  // The first claim is arguable, so it is thrown away and a second one written.
  judged = [];
  q = await viva(fakeModel({ claims: ['Binary search is always the best way to search.', 'Binary search works on unsorted lists.'], verdicts: [false, true], judged }));
  assert.match(q, /works on unsorted lists/);

  // Nothing passes, or the model is down: the question's stored claim is used.
  const stored = rubrics.get('binary_search').trap.false_claim;
  for (const model of [{ claims: ['a claim', 'b claim'], verdicts: [false, false] }, { claims: ['down'], verdicts: [] }]) {
    judged = [];
    q = await viva(fakeModel({ ...model, judged }));
    assert.equal(q, `A classmate told me: “${stored}” Do you agree?`);
    assert.ok(judged[0].includes(stored));
  }
});

test('model failure is a 502, and a failing question falls back to the rubric', async () => {
  const llm = async ({ prompt }) => {
    if (prompt.includes('For EVERY rubric point')) throw new AiError('down');
    return {};
  };
  const { call, close } = await boot({ llm });
  try {
    const r = await call('POST', '/sessions', { student_name: 'Al', question_id: 'binary_search', answer_text: ANSWER });
    assert.equal(r.status, 502);
    assert.equal(r.body.error, 'The duck is having trouble thinking. Please try again.');
  } finally {
    await close();
  }
});

test('transcription validates the photo and flags unclear handwriting', async () => {
  const { call, close } = await boot();
  try {
    const png = Buffer.from('fake image bytes').toString('base64');
    assert.equal((await call('POST', '/transcribe', { question_id: 'binary_search', image_base64: png, mime_type: 'image/gif' })).status, 400);
    const r = await call('POST', '/transcribe', { question_id: 'binary_search', image_base64: png, mime_type: 'image/png' });
    assert.equal(r.status, 200);
    assert.equal(r.body.legibility, 'unclear');
    assert.equal(r.body.unclear_words, 1);
  } finally {
    await close();
  }
});

test('a multi-page document or PDF is transcribed as one answer', async () => {
  const { call, close } = await boot();
  try {
    const page = Buffer.from('fake page bytes').toString('base64');
    const pdf = { image_base64: page, mime_type: 'application/pdf' };
    const r = await call('POST', '/transcribe', { question_id: 'binary_search', pages: [pdf] });
    assert.equal(r.status, 200);
    assert.match(r.body.text, /sorted/);
    const two = await call('POST', '/transcribe', { question_id: 'binary_search', pages: [{ image_base64: page, mime_type: 'image/jpeg' }, { image_base64: page, mime_type: 'image/png' }] });
    assert.equal(two.status, 200);
    const tooMany = await call('POST', '/transcribe', { question_id: 'binary_search', pages: Array(11).fill(pdf) });
    assert.equal(tooMany.status, 400);
    assert.match(tooMany.body.error, /10 JPEG or PNG pages/);
    assert.equal((await call('POST', '/transcribe', { pages: [{ image_base64: page, mime_type: 'image/gif' }] })).status, 400);

    // A photographed document is graded with the handwriting flag, like a photo.
    const created = await call('POST', '/sessions', {
      student_name: 'Dee', question_id: 'binary_search', answer_text: r.body.text, source: 'document',
      transcription: { legibility: r.body.legibility, confidence: r.body.confidence, edited: false },
    });
    assert.equal(created.status, 201);
    assert.ok(created.body.grade.review.reasons.some((x) => x.code === 'handwriting'));
  } finally {
    await close();
  }
});

test('teachers scan a whole answer sheet and grade every question on it (contract 10)', async () => {
  const { call, close } = await boot({ seed: { samples: false, demoAccounts: true } });
  try {
    const teacher = await login(call, 'teacher@vivduck.test');
    const student = await login(call, 'student@vivduck.test');
    const pages = [{ image_base64: Buffer.from('sheet').toString('base64'), mime_type: 'application/pdf' }];
    const ids = ['binary_search', 'normalisation'];

    assert.equal((await call('POST', '/teacher/sheets/read', { question_ids: ids, pages })).status, 401);
    assert.equal((await call('POST', '/teacher/sheets/read', { question_ids: ids, pages }, student)).status, 403);
    assert.equal((await call('POST', '/teacher/sheets/read', { question_ids: ['nope'], pages }, teacher)).status, 400);
    assert.equal((await call('POST', '/teacher/sheets/read', { question_ids: ['binary_search', 'binary_search'], pages }, teacher)).status, 400);

    const read = await call('POST', '/teacher/sheets/read', { question_ids: ids, pages }, teacher);
    assert.equal(read.status, 200);
    assert.deepEqual(read.body.answers.map((a) => a.question_id), ids, 'one answer per question, in order');
    assert.ok(read.body.answers.every((a) => a.found && a.text));

    // The teacher keeps the first answer and finds no answer to the second.
    const [a1] = read.body.answers;
    const graded = await call('POST', '/teacher/sheets', {
      student_name: 'Riya',
      answers: [
        { question_id: a1.question_id, text: a1.text, transcription: { legibility: a1.legibility, confidence: a1.confidence } },
        { question_id: 'normalisation', text: '' },
      ],
    }, teacher);
    assert.equal(graded.status, 201);
    const sh = graded.body;
    assert.equal(sh.items.length, 2);
    assert.equal(sh.answered, 1);
    const [q1, q2] = sh.items;
    assert.ok(q1.score > 0);
    assert.equal(q1.marks, Math.round((q1.score / 100) * q1.max_marks * 2) / 2);
    for (const p of q1.grade.points) if (p.status !== 'missing') assert.ok(a1.text.includes(p.evidence_quote));
    assert.equal(q2.answered, false);
    assert.equal(q2.marks, 0);
    assert.ok(q2.grade.points.every((p) => p.status === 'missing'));
    assert.equal(sh.total_marks, q1.marks);
    assert.equal(sh.max_marks, q1.max_marks + q2.max_marks);
    assert.equal(sh.needs_review, true, 'unclear handwriting is flagged');

    const list = (await call('GET', '/teacher/sheets', undefined, teacher)).body.sheets;
    assert.equal(list.length, 1);
    assert.equal(list[0].sheet_id, sh.sheet_id);
    assert.equal((await call('GET', `/teacher/sheets/${sh.sheet_id}`, undefined, teacher)).body.items.length, 2);
    assert.equal((await call('GET', '/teacher/sheets/sh_missing', undefined, teacher)).status, 404);
  } finally {
    await close();
  }
});

test('with no model and no offline flag, grading is refused rather than faked', async () => {
  const { createApp } = await import('../server/app.js');
  const { createEngine } = await import('../ai/index.js');
  const app = createApp({ engine: createEngine({ llm: null, offline: false }), publicDir: null, seed: {} });
  const server = await new Promise((r) => { const s = app.listen(0, () => r(s)); });
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    const health = await (await fetch(`${base}/health`)).json();
    assert.equal(health.ai, 'not_configured');
    const res = await fetch(`${base}/sessions`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ student_name: 'A', question_id: 'binary_search', answer_text: 'x' }),
    });
    assert.equal(res.status, 503);
    const summary = await fetch(`${base}/questions`);
    assert.equal(summary.status, 200, 'non-AI routes still work');
  } finally {
    await new Promise((r) => server.close(r));
  }
});

test('a signed-in user can edit their name and change their password (contract 11)', async () => {
  const { call, close } = await boot();
  try {
    const reg = await call('POST', '/auth/register', { name: 'Riya', email: 'riya@example.com', password: 'first-pass', role: 'student' });
    const token = reg.body.token;
    const other = (await call('POST', '/auth/login', { email: 'riya@example.com', password: 'first-pass' })).body.token;

    assert.equal((await call('GET', '/auth/me')).status, 401);
    assert.equal((await call('GET', '/auth/me', undefined, token)).body.user.name, 'Riya');
    assert.equal((await call('PATCH', '/auth/me', { name: '  ' }, token)).status, 400);
    const renamed = await call('PATCH', '/auth/me', { name: 'Riya Sharma' }, token);
    assert.equal(renamed.body.user.name, 'Riya Sharma');
    assert.equal(renamed.body.user.password, undefined);

    assert.equal((await call('POST', '/auth/password', { current_password: 'wrong', new_password: 'second-pass' }, token)).status, 401);
    assert.equal((await call('POST', '/auth/password', { current_password: 'first-pass', new_password: 'short' }, token)).status, 400);
    assert.equal((await call('POST', '/auth/password', { current_password: 'first-pass', new_password: 'second-pass' }, token)).status, 200);
    assert.equal((await call('GET', '/auth/me', undefined, token)).status, 200, 'this device stays signed in');
    assert.equal((await call('GET', '/auth/me', undefined, other)).status, 401, 'other devices are signed out');
    assert.equal((await call('POST', '/auth/login', { email: 'riya@example.com', password: 'first-pass' })).status, 401);
    assert.equal((await call('POST', '/auth/login', { email: 'riya@example.com', password: 'second-pass' })).status, 200);

    const demo = (await call('POST', '/auth/login', { email: 'student@vivduck.test', password: 'quack-quack-1' })).body.token;
    assert.equal((await call('PATCH', '/auth/me', { name: 'Hacked' }, demo)).status, 403);
    assert.equal((await call('POST', '/auth/password', { current_password: 'quack-quack-1', new_password: 'locked-out' }, demo)).status, 403);
  } finally {
    await close();
  }
});

test('teacher accounts need the invite code when one is set', async () => {
  const { call, close } = await boot({ teacherInviteCode: 'pond-42' });
  try {
    const base = { name: 'T', email: 't@example.com', password: 'longenough', role: 'teacher' };
    assert.equal((await call('POST', '/auth/register', base)).status, 403);
    assert.equal((await call('POST', '/auth/register', { ...base, invite_code: 'wrong' })).status, 403);
    assert.equal((await call('POST', '/auth/register', { ...base, invite_code: 'pond-42' })).status, 201);
    const student = { name: 'S', email: 's@example.com', password: 'longenough', role: 'student' };
    assert.equal((await call('POST', '/auth/register', student)).status, 201, 'students never need a code');
  } finally {
    await close();
  }
});

// A fake model that can draft rubrics, grade and judge.
const DRAFT = {
  answerable: true,
  title: 'Photosynthesis',
  subject: 'Biology',
  points: [
    { statement: 'Plants convert light energy into chemical energy.', weight: 3, hint: 'Say what energy changes.', probe: 'Where does the energy end up?' },
    { statement: 'Chlorophyll in chloroplasts absorbs light.', weight: 2, hint: 'Name the pigment.', probe: 'What absorbs the light?' },
    { statement: 'Carbon dioxide and water are used, and oxygen is released.', weight: 2, hint: 'Give inputs and outputs.', probe: 'What gas is released?' },
  ],
  trap_false_claim: 'Plants get most of their mass from the soil.',
  trap_truth: 'Most of the mass comes from carbon dioxide in the air.',
  what_if: 'What if the plant were kept in the dark?',
};
const draftingLlm = async ({ prompt }) => {
  if (prompt.includes('Write a marking rubric')) {
    return prompt.includes('hello there') ? { ...DRAFT, answerable: false } : DRAFT;
  }
  if (prompt.includes('deliberately FALSE')) {
    return { points: [], trap_caught: true, trap_explanation: 'The student rejected it.', bloom_reached: 'Analyse' };
  }
  if (prompt.includes('For EVERY rubric point')) {
    return { points: [{ id: 'kp1', status: 'solid', evidence_quote: 'Plants turn light into chemical energy', comment: 'Good.' }] };
  }
  return { question: 'Tell me more?' };
};
const PHOTO_ANSWER = 'Plants turn light into chemical energy that they store as sugar.';

test('teachers draft, edit, publish and remove their own questions', async () => {
  const { call, close } = await boot({ llm: draftingLlm, seed: { samples: false, demoAccounts: true } });
  try {
    const teacher = await login(call, 'teacher@vivduck.test');
    const student = await login(call, 'student@vivduck.test');
    const prompt = 'Explain how photosynthesis works and why it matters.';
    assert.equal((await call('POST', '/questions/draft', { prompt }, student)).status, 403);
    const d = await call('POST', '/questions/draft', { prompt, marks: 20 }, teacher);
    assert.equal(d.status, 200);
    assert.equal(d.body.draft.points.length, 3);
    assert.equal(d.body.draft.marks, 20);
    assert.equal((await call('POST', '/questions/draft', { prompt: 'hello there friend' }, teacher)).status, 422);

    // The teacher drops a point and edits the trap before publishing.
    const edited = { ...d.body.draft, points: d.body.draft.points.slice(0, 2), trap: { ...d.body.draft.trap, truth: 'Edited.' } };
    const pub = await call('POST', '/questions', edited, teacher);
    assert.equal(pub.status, 201);
    const qid = pub.body.question.id;
    assert.equal(pub.body.question.points, 2);

    const list = (await call('GET', '/questions')).body.questions;
    assert.equal(list[0].id, qid, 'teacher questions come first');
    assert.equal(list[0].origin, 'teacher');
    assert.equal(list.at(-1).origin, 'sample');

    const s = await call('POST', '/sessions', { student_name: 'S', question_id: qid, answer_text: PHOTO_ANSWER }, student);
    assert.equal(s.status, 201);
    assert.equal(s.body.grade.points.length, 2);
    assert.equal(s.body.grade.points[0].status, 'solid');
    assert.ok(!s.body.grade.review.reasons.some((r) => r.code === 'ai_rubric'), 'teacher-approved rubric is not flagged');

    assert.equal((await call('DELETE', `/questions/${qid}`, undefined, teacher)).status, 200);
    assert.ok(!(await call('GET', '/questions')).body.questions.some((q) => q.id === qid));
    // Old sessions on a removed question still have their rubric.
    for (const text of ['a', 'b', 'no']) await call('POST', `/sessions/${s.body.session_id}/turn`, { text }, student);
    assert.equal((await call('GET', `/sessions/${s.body.session_id}/report`, undefined, student)).body.title, 'Photosynthesis');
  } finally {
    await close();
  }
});

test('students can answer their own question; the AI rubric is flagged for a teacher', async () => {
  const { call, close } = await boot({ llm: draftingLlm, seed: { samples: false, demoAccounts: true } });
  try {
    const custom = { prompt: 'Explain how photosynthesis works.', subject: 'Biology' };
    const r = await call('POST', '/sessions', { student_name: 'S', custom_question: custom, answer_text: PHOTO_ANSWER });
    assert.equal(r.status, 201);
    assert.equal(r.body.question_info.title, 'Photosynthesis');
    assert.ok(r.body.grade.review.reasons.some((x) => x.code === 'ai_rubric'));
    assert.ok(!(await call('GET', '/questions')).body.questions.some((q) => q.title === 'Photosynthesis'), 'not listed for others');

    const notQ = await call('POST', '/sessions', { student_name: 'S', custom_question: { prompt: 'hello there friend' }, answer_text: 'hi' });
    assert.equal(notQ.status, 422);
    const both = await call('POST', '/sessions', { student_name: 'S', question_id: 'binary_search', custom_question: custom, answer_text: 'x' });
    assert.equal(both.status, 400);
    const neither = await call('POST', '/sessions', { student_name: 'S', answer_text: 'x' });
    assert.equal(neither.status, 400);
  } finally {
    await close();
  }
});
