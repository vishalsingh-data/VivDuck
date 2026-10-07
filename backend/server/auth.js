// Accounts (contracts 05 and 06). Passwords are hashed with scrypt; tokens are
// random and sent back as "Authorization: Bearer <token>".
import crypto from 'node:crypto';

export function hashPassword(password, salt = crypto.randomBytes(16).toString('hex')) {
  const hash = crypto.scryptSync(password, salt, 32).toString('hex');
  return `${salt}:${hash}`;
}

export function checkPassword(password, stored) {
  const [salt, hash] = String(stored).split(':');
  if (!salt || !hash) return false;
  const got = Buffer.from(hashPassword(password, salt).split(':')[1], 'hex');
  const want = Buffer.from(hash, 'hex');
  return got.length === want.length && crypto.timingSafeEqual(got, want);
}

export const newId = (prefix, bytes = 3) => `${prefix}_${crypto.randomBytes(bytes).toString('hex')}`;
export const newToken = () => `tok_${crypto.randomBytes(24).toString('base64url')}`;

export const publicUser = (u) => ({ id: u.id, name: u.name, email: u.email, role: u.role });

/** Demo accounts for judges and teammates. Same logins as the app's demo mode. */
export const DEMO_ACCOUNTS = [
  { id: 'u_demo_s', name: 'Alice Nguyen', email: 'student@vivduck.test', role: 'student' },
  { id: 'u_demo_t', name: 'Ms. Rivera', email: 'teacher@vivduck.test', role: 'teacher' },
];
export const DEMO_PASSWORD = 'quack-quack-1';

/** Express middleware: attaches req.user when a valid token is sent. */
export function attachUser(store) {
  return (req, _res, next) => {
    const m = /^Bearer\s+(.+)$/i.exec(req.get('authorization') ?? '');
    req.user = m ? store.userByToken(m[1].trim()) : null;
    next();
  };
}

export function requireTeacher(req, res, next) {
  if (!req.user) return res.status(401).json({ error: 'Please sign in first.' });
  if (req.user.role !== 'teacher') return res.status(403).json({ error: 'Only teachers can open the class dashboard.' });
  next();
}
