// Loads backend/.env wherever the server is started from. Imported first by
// server.js, before anything reads process.env.
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

const backendDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
dotenv.config({ path: path.join(backendDir, '.env'), quiet: true });

// A relative DATA_DIR means relative to backend/, not to the current directory.
if (process.env.DATA_DIR && !path.isAbsolute(process.env.DATA_DIR)) {
  process.env.DATA_DIR = path.join(backendDir, process.env.DATA_DIR);
}
