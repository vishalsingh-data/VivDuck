import { GoogleGenAI } from '@google/genai';

const TIMEOUT_MS = 45_000;

function getConfig() {
  const apiKey = process.env.LLM_API_KEY;
  const model = process.env.LLM_MODEL;

  if (!apiKey) {
    throw new Error('LLM_API_KEY is not configured');
  }

  if (!model) {
    throw new Error('LLM_MODEL is not configured');
  }

  return { apiKey, model };
}

async function generateWithTimeout(ai, model, contents) {
  return Promise.race([
    ai.models.generateContent({
      model,
      contents,
    }),
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error('LLM request timed out after 45 seconds')), TIMEOUT_MS)
    ),
  ]);
}

/**
 * Call Gemini and return validated JSON.
 *
 * @param {object} options
 * @param {string} options.system - System instruction.
 * @param {string} options.user - User prompt.
 * @param {{ parse: (value: unknown) => any }} options.schema - Zod schema.
 * @returns {Promise<any>}
 */
export async function callJson({ system, user, schema }) {
  const { apiKey, model } = getConfig();
  const ai = new GoogleGenAI({ apiKey });

  let lastError;

  for (let attempt = 0; attempt < 2; attempt += 1) {
    try {
      const response = await generateWithTimeout(ai, model, [
        {
          role: 'user',
          parts: [
            {
              text: `${system}\n\nReturn ONLY valid JSON.\n\n${user}`,
            },
          ],
        },
      ]);

      const raw = response.text?.trim();

      if (!raw) {
        throw new Error('LLM returned an empty response');
      }

      let parsed;

      try {
        parsed = JSON.parse(raw);
      } catch {
        throw new Error('LLM returned invalid JSON');
      }

      return schema.parse(parsed);
    } catch (error) {
      lastError = error;

      if (attempt === 0) {
        continue;
      }
    }
  }

  throw new Error(`LLM JSON request failed: ${lastError?.message ?? 'unknown error'}`);
}