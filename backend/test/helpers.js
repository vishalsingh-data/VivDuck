import { createApp } from '../server/app.js';
import { Store } from '../server/store.js';
import { createEngine } from '../ai/index.js';

/** Boots the app on a free port. llm = null uses the offline grader. */
export async function boot({ llm = null, seed = { samples: true, demoAccounts: true }, teacherInviteCode = null } = {}) {
  const store = new Store(null);
  const app = createApp({ engine: createEngine({ llm, offline: true }), store, publicDir: null, seed, limits: { aiPerMinute: 1000 }, teacherInviteCode });
  const server = await new Promise((resolve) => {
    const s = app.listen(0, () => resolve(s));
  });
  const base = `http://127.0.0.1:${server.address().port}`;
  const call = async (method, path, body, token) => {
    const res = await fetch(base + path, {
      method,
      headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    return { status: res.status, body: await res.json() };
  };
  return { store, call, close: () => new Promise((r) => server.close(r)) };
}

export const ANSWER =
  'Binary search only works on a sorted list. It looks at the middle element and compares it with the target. If the target is bigger it throws away the left half, otherwise the right half. It keeps halving until it finds the value or there is nothing left, so it takes about log n steps.';
