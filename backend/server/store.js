// A small JSON-file store. Enough for a class: everything lives in memory and
// is flushed to DATA_DIR/vivduck.json after each change. With no DATA_DIR
// (tests) nothing touches disk.
import fs from 'node:fs';
import path from 'node:path';

const EMPTY = () => ({ users: [], tokens: {}, sessions: {}, questions: {}, sheets: {} });

export class Store {
  constructor(dir = null) {
    this.file = dir ? path.join(dir, 'vivduck.json') : null;
    this.data = EMPTY();
    this._timer = null;
    if (this.file && fs.existsSync(this.file)) {
      try {
        this.data = { ...EMPTY(), ...JSON.parse(fs.readFileSync(this.file, 'utf8')) };
      } catch (e) {
        console.error(`[store] could not read ${this.file}, starting empty:`, e.message);
      }
    }
  }

  get isEmpty() {
    return this.data.users.length === 0 && Object.keys(this.data.sessions).length === 0;
  }

  /** Coalesces writes; the file is replaced atomically. */
  save() {
    if (!this.file || this._timer) return;
    this._timer = setTimeout(() => {
      this._timer = null;
      this.flush();
    }, 50);
  }

  flush() {
    if (!this.file) return;
    fs.mkdirSync(path.dirname(this.file), { recursive: true });
    const tmp = `${this.file}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(this.data));
    fs.renameSync(tmp, this.file);
  }

  // Users & tokens
  userByEmail(email) {
    return this.data.users.find((u) => u.email === email.toLowerCase()) ?? null;
  }
  userByToken(token) {
    const id = this.data.tokens[token];
    return id ? (this.data.users.find((u) => u.id === id) ?? null) : null;
  }
  addUser(user) {
    this.data.users.push(user);
    this.save();
    return user;
  }
  addToken(token, userId) {
    this.data.tokens[token] = userId;
    this.save();
  }
  /** Signs a user out everywhere except [keep] (after a password change). */
  dropTokens(userId, keep = null) {
    for (const [t, id] of Object.entries(this.data.tokens)) {
      if (id === userId && t !== keep) delete this.data.tokens[t];
    }
    this.save();
  }

  // Questions written by teachers or students (rubric + who/when)
  question(id) {
    return this.data.questions[id] ?? null;
  }
  putQuestion(q) {
    this.data.questions[q.id] = q;
    this.save();
    return q;
  }
  questions() {
    return Object.values(this.data.questions);
  }

  // Sessions
  session(id) {
    return this.data.sessions[id] ?? null;
  }
  putSession(s) {
    this.data.sessions[s.id] = s;
    this.save();
    return s;
  }
  sessions() {
    return Object.values(this.data.sessions);
  }

  // Whole answer sheets a teacher scanned and graded
  sheet(id) {
    return this.data.sheets[id] ?? null;
  }
  putSheet(s) {
    this.data.sheets[s.id] = s;
    this.save();
    return s;
  }
  sheets() {
    return Object.values(this.data.sheets);
  }
}
