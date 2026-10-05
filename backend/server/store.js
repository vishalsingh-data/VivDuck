import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const SESSIONS_FILE = path.join(__dirname, '..', 'sessions.json');

const sessions = new Map();

function saveSessions() {
  const data = Object.fromEntries(sessions);
  try {
    fs.writeFileSync(SESSIONS_FILE, JSON.stringify(data, null, 2), 'utf-8');
  } catch (err) {
    console.error(`Failed to save sessions: ${err.message}`);
  }
}

function loadSessions() {
  sessions.clear();
  try {
    if (fs.existsSync(SESSIONS_FILE)) {
      const content = fs.readFileSync(SESSIONS_FILE, 'utf-8');
      const data = JSON.parse(content);
      for (const [key, value] of Object.entries(data)) {
        sessions.set(key, value);
      }
    }
  } catch (err) {
    console.warn(`Warning: Could not load sessions from ${SESSIONS_FILE}. Starting empty. Error: ${err.message}`);
  }
}

// Load on startup
loadSessions();

export function createSession(data) {
  const id = 's_' + Math.random().toString(36).substring(2, 6);
  sessions.set(id, { id, ...data });
  saveSessions();
  return id;
}

export function getSession(id) {
  return sessions.get(id);
}

export function updateSession(id, changes) {
  if (sessions.has(id)) {
    const session = sessions.get(id);
    sessions.set(id, { ...session, ...changes });
    saveSessions();
    return sessions.get(id);
  }
  return null;
}

export function listSessions() {
  return Array.from(sessions.values());
}

// Expose for testing so we can simulate a reload without a full process restart
export function _reloadForTest() {
  loadSessions();
}
