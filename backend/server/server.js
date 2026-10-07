import 'dotenv/config';
import { createApp } from './app.js';
import { Store } from './store.js';
import { createEngine } from '../ai/index.js';

const PORT = process.env.PORT ?? 8000;
const engine = createEngine();
const store = new Store(process.env.DATA_DIR || null);
const app = createApp({ engine, store });

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`VivDuck listening on http://0.0.0.0:${PORT}`);
  console.log(
    {
      gemini: `AI: Gemini (${engine.model})`,
      offline: 'AI: offline keyword grader (OFFLINE_GRADER=true)',
      not_configured: 'AI: NOT CONFIGURED. Set LLM_API_KEY; grading returns 503 until then.',
    }[engine.mode],
  );
  console.log(`Data: ${store.file ?? 'in memory only (set DATA_DIR to keep it)'}`);
});

for (const sig of ['SIGTERM', 'SIGINT']) {
  process.on(sig, () => {
    store.flush();
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(0), 3000).unref();
  });
}
