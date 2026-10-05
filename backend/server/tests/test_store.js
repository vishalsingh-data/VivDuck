import { test } from 'node:test';
import assert from 'node:assert';
import { createSession, getSession, updateSession, listSessions, _reloadForTest } from '../store.js';

test('create, read, update, list sessions', () => {
  // Create
  const data = { user: 'TestUser123' };
  const id = createSession(data);
  assert.ok(id.startsWith('s_'), 'Session ID should start with s_');
  assert.strictEqual(id.length, 6, 'Session ID should be short (e.g. s_k3f9)');

  // Read
  const session = getSession(id);
  assert.strictEqual(session.user, 'TestUser123', 'Should retrieve the created session');

  // Update
  updateSession(id, { score: 42 });
  const updatedSession = getSession(id);
  assert.strictEqual(updatedSession.score, 42, 'Session should be updated with new fields');
  assert.strictEqual(updatedSession.user, 'TestUser123', 'Session should keep existing fields');

  // List
  const sessions = listSessions();
  const found = sessions.find(s => s.id === id);
  assert.ok(found, 'Created session should be in the list');
  assert.strictEqual(found.score, 42, 'List should reflect updates');
});

test('reload from file', () => {
  const data = { user: 'ReloadUser' };
  const id = createSession(data);
  
  // Simulate a restart by reloading the file from disk (drops the current map and replaces it)
  _reloadForTest();
  
  const reloadedSession = getSession(id);
  assert.ok(reloadedSession, 'Session should be loaded from the JSON file');
  assert.strictEqual(reloadedSession.user, 'ReloadUser', 'Reloaded session should have correct data');
});
