// Gemini with schema-validated structured output. Every response is parsed
// and checked against a zod schema; anything that doesn't fit is retried, then
// reported as an AiError (the routes turn that into a 502).
import { GoogleGenAI } from '@google/genai';
import { z } from 'zod';

export class AiError extends Error {}

const apiKey = process.env.LLM_API_KEY || process.env.GEMINI_API_KEY || '';
export const MODEL = process.env.LLM_MODEL || 'gemini-flash-lite-latest';
/** Tried in order when a model is overloaded (503) or out of quota (429). */
const FALLBACKS = (process.env.LLM_FALLBACK_MODELS ?? 'gemini-3.5-flash-lite,gemini-flash-latest')
  .split(',')
  .map((m) => m.trim())
  .filter((m) => m && m !== MODEL);
const MODELS = [MODEL, ...FALLBACKS];
const TIMEOUT_MS = Number(process.env.LLM_TIMEOUT_MS ?? 45000);
/** Give up on a request after this long, retries included. */
const BUDGET_MS = Number(process.env.LLM_BUDGET_MS ?? 60000);

const busyError = (e) => e?.status === 429 || e?.status === 503 || e?.status === 500;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** How long Google asked us to wait ("Please retry in 3.9s"), capped. */
function retryDelayMs(e) {
  const m = /retry in ([\d.]+)s/i.exec(String(e?.message ?? ''));
  return Math.min(m ? Number(m[1]) * 1000 + 250 : 2000, 10000);
}

const client = apiKey ? new GoogleGenAI({ apiKey }) : null;

function jsonSchemaOf(schema) {
  const { $schema, ...rest } = z.toJSONSchema(schema);
  return rest;
}

function withTimeout(promise, ms) {
  let timer;
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      timer = setTimeout(() => reject(new AiError(`model timed out after ${ms} ms`)), ms);
    }),
  ]).finally(() => clearTimeout(timer));
}

/**
 * Asks the model for JSON matching [schema].
 * files are photos or PDFs sent with the prompt, in order (one image is the same as files: [image]).
 * @param {{ system: string, prompt: string, schema: import('zod').ZodType,
 *           image?: { mimeType: string, data: string },
 *           files?: { mimeType: string, data: string }[], temperature?: number }} opts
 */
async function generateJson({ system, prompt, schema, image, files, temperature = 0.2 }) {
  const parts = [{ text: prompt }];
  for (const f of files ?? (image ? [image] : [])) parts.push({ inlineData: { mimeType: f.mimeType, data: f.data } });
  const config = {
    systemInstruction: system,
    temperature,
    responseMimeType: 'application/json',
    responseJsonSchema: jsonSchemaOf(schema),
  };
  const deadline = Date.now() + BUDGET_MS;
  let lastError;
  let invalid = 0;
  let i = 0;
  while (Date.now() < deadline) {
    const model = MODELS[i % MODELS.length];
    try {
      const res = await withTimeout(
        client.models.generateContent({ model, contents: [{ role: 'user', parts }], config }),
        TIMEOUT_MS,
      );
      const parsed = schema.safeParse(JSON.parse(res.text ?? ''));
      if (parsed.success) return parsed.data;
      lastError = new AiError(`${model} output failed validation: ${parsed.error.message}`);
      if (++invalid >= 2) break;
    } catch (e) {
      lastError = e;
      if (!busyError(e)) {
        if (++invalid >= 2) break;
      } else {
        console.warn(`[ai] ${model} busy (${e.status}), trying ${MODELS[(i + 1) % MODELS.length]}`);
        // Every model has been tried this round: wait as long as Google asks.
        if ((i + 1) % MODELS.length === 0) await sleep(retryDelayMs(e));
      }
    }
    i++;
  }
  console.error('[ai]', lastError?.message ?? lastError);
  throw lastError instanceof AiError ? lastError : new AiError(String(lastError?.message ?? lastError));
}

/** The live model, or null when no API key is set. */
export const gemini = client ? generateJson : null;
