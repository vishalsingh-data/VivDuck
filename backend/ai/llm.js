// Gemini with schema-validated structured output. Every response is parsed
// and checked against a zod schema; anything that doesn't fit is retried, then
// reported as an AiError (the routes turn that into a 502).
import { GoogleGenAI } from '@google/genai';
import { z } from 'zod';

export class AiError extends Error {}

const apiKey = process.env.LLM_API_KEY || process.env.GEMINI_API_KEY || '';
export const MODEL = process.env.LLM_MODEL || 'gemini-flash-latest';
const TIMEOUT_MS = Number(process.env.LLM_TIMEOUT_MS ?? 45000);

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
 * @param {{ system: string, prompt: string, schema: import('zod').ZodType,
 *           image?: { mimeType: string, data: string }, temperature?: number }} opts
 */
async function generateJson({ system, prompt, schema, image, temperature = 0.2, attempts = 2 }) {
  const parts = [{ text: prompt }];
  if (image) parts.push({ inlineData: { mimeType: image.mimeType, data: image.data } });
  let lastError;
  for (let i = 0; i < attempts; i++) {
    try {
      const res = await withTimeout(
        client.models.generateContent({
          model: MODEL,
          contents: [{ role: 'user', parts }],
          config: {
            systemInstruction: system,
            temperature,
            responseMimeType: 'application/json',
            responseJsonSchema: jsonSchemaOf(schema),
          },
        }),
        TIMEOUT_MS,
      );
      const parsed = schema.safeParse(JSON.parse(res.text ?? ''));
      if (parsed.success) return parsed.data;
      lastError = new AiError(`model output failed validation: ${parsed.error.message}`);
    } catch (e) {
      lastError = e;
    }
  }
  console.error('[ai]', lastError?.message ?? lastError);
  throw lastError instanceof AiError ? lastError : new AiError(String(lastError?.message ?? lastError));
}

/** The live model, or null when no API key is set (offline grader is used). */
export const gemini = client ? generateJson : null;
