# VivDuck

The AI examiner that grades your answer, then asks if you really understand it.

- Grades a descriptive answer (typed or a photo of handwriting) against the teacher's rubric.
- Every mark cites the student's own words. The quote is checked in code; a quote that isn't really in the answer earns nothing.
- Grades twice and flags the answer for a teacher when the two runs disagree, the answer was pasted, or the handwriting was hard to read.
- Runs a short viva: a probe on the weakest point, a what-if, and a deliberately false claim the student must catch.
- Gives the teacher a dashboard: scores, review queue, agreement with their own marks, and the concepts the class is weakest on.

**The AI never decides the score.** Gemini labels each rubric point solid, partial or missing, with a quote. Fixed rules in [`backend/ai/scoring.js`](backend/ai/scoring.js) verify the quotes and compute the marks.

## Layout

| Path | What |
|------|------|
| `app/` | Flutter app (web, Android, iOS). See [`app/BUILD.md`](app/BUILD.md). |
| `backend/server/` | Express API: every route in `shared/contracts/`, and serves the web build. |
| `backend/ai/` | Gemini prompts and schemas (`index.js`), scoring rules (`scoring.js`), offline grader (`keyword.js`). |
| `shared/contracts/` | API contracts (request, response, errors). |
| `shared/rubrics/` | Question rubrics, with key points, weights, trap claim and follow-ups. |

## Run locally

```bash
cd backend && npm install && cp .env.example .env   # put your Gemini key in LLM_API_KEY
cd ../app && flutter build web --dart-define=API_BASE_URL=same-origin
cd ../backend && npm start                           # http://localhost:8000
```

Grading needs `LLM_API_KEY`. Without it the server still starts, but grading and transcription answer 503 until a key is set; `GET /health` shows `"ai":"gemini"` once it's working. There is no fake grading unless you ask for it with `OFFLINE_GRADER=true` (keyword matching, for a demo with no network).

During development, `cd app && flutter run -d chrome` talks to the local server on port 8000. Register an account in the app to get started.

Optional demo logins, created only with `SEED_DEMO_ACCOUNTS=true`:

| Role | Email | Password |
|------|-------|----------|
| Student | `student@vivduck.test` | `quack-quack-1` |
| Teacher | `teacher@vivduck.test` | `quack-quack-1` |

## Tests

```bash
cd backend && npm test
cd app && flutter test --dart-define=API_BASE_URL=mock   # app tests use bundled fixtures
```

## Deploy

One Docker image builds the web app and serves it with the API on one port.

```bash
docker build -t vivduck .
docker run -p 8000:8000 -e LLM_API_KEY=your-key -v vivduck-data:/data vivduck
```

**Render:** push to GitHub, then New > Blueprint and pick the repo. `render.yaml` sets everything up; paste your Gemini key and pick a teacher invite code when asked. The same image runs on Google Cloud Run, Fly.io or Railway; set `LLM_API_KEY`, and mount a volume at `/data` if you want sessions to survive restarts.

**Android:** `cd app && flutter build apk --dart-define=API_BASE_URL=https://your-deployment-url`.

### Settings

| Variable | Default | |
|----------|---------|-|
| `LLM_API_KEY` | (empty) | Gemini API key. Required for grading. `GEMINI_API_KEY` also works. |
| `TEACHER_INVITE_CODE` | (empty) | When set, registering as a teacher needs this code. Students never do. Empty means anyone can register as a teacher. |
| `LLM_MODEL` | `gemini-flash-lite-latest` | Any Gemini model with structured output. The lite model has the most free-tier headroom. |
| `LLM_FALLBACK_MODELS` | `gemini-3.5-flash-lite,gemini-flash-latest` | Tried in turn when a model is busy (503) or out of quota (429). |
| `DATA_DIR` | `/data` in Docker | Where accounts and sessions are saved. Empty means memory only. |
| `PUBLIC_DIR` | `/srv/public` in Docker | The Flutter web build to serve at `/`. |
| `SEED_SAMPLES` | `false` | `true` adds 14 made-up sample sessions to the dashboard. |
| `SEED_DEMO_ACCOUNTS` | `false` | `true` adds the demo logins above. |
| `OFFLINE_GRADER` | `false` | `true` grades by keyword matching instead of Gemini. |
| `AI_RATE_PER_MINUTE` | `40` | Per-IP limit on the AI routes. |
