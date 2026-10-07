import { test } from 'node:test';
import assert from 'node:assert/strict';

import { boot, ANSWER } from './helpers.js';
import { AiError } from '../ai/llm.js';

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
