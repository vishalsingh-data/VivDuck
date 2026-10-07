# VivDuck app — build & run

One Flutter codebase for web, Android and iOS. Layouts adapt at 720px (tablet) and 1080px (desktop).

## Modes

| Mode | How | What it does |
|------|-----|--------------|
| Live (default) | no flags | Debug: the local server at `http://localhost:8000` (`10.0.2.2` on the Android emulator). Web release: the server that served the page. |
| Live, other server | `--dart-define=API_BASE_URL=https://your-server` | Calls that server. Use this for Android/iOS release builds. |
| Mock | `--dart-define=API_BASE_URL=mock` | Bundled fixtures, no network. Used by `flutter test`. Shows a "Demo mode" pill. |

On the Android emulator, the host machine is `http://10.0.2.2:8000`.

## Commands

```bash
cd app
flutter pub get
flutter run -d chrome                                   # web, against the local server
flutter run -d chrome --dart-define=API_BASE_URL=mock    # web, no server
flutter run -d <android-or-ios-device-id>
flutter build web                                       # output: build/web
flutter build apk --dart-define=API_BASE_URL=https://your-server
flutter test --dart-define=API_BASE_URL=mock
```

## Layout

```
lib/
  main.dart
  core/            shared: theme, models (match contracts), api (HTTP + mock), auth, duck mascot, widgets
  auth/            login / register screen
  home/            landing page
  viva/            submission form + turn-by-turn viva chat        (track-c)
  report_teacher/  student report + teacher dashboard, charts      (track-d)
```

## Notes

- **Paste detection:** if a single edit inserts 25 or more characters, that answer is sent with `pasted: true`.
- **Report polling:** the report screen retries on `409 viva is still in progress` for about 10 seconds before showing an error.
- **Trap label:** the trap question appears to the student as a "Curveball". The report then says whether they caught it.

## Accounts

- **Endpoints:** `POST /auth/register` and `POST /auth/login` (see `shared/contracts/05_register.json` and `06_login.json`). Both return `{ token, user }`.
- **Token:** the app saves it on the device and sends `Authorization: Bearer <token>` on every viva and teacher request.
- **Sign-in gates:** students and teachers can both start a viva. Only teacher accounts can open the class dashboard. The landing page is public.
- **Mock mode:** you can log in with the seeded accounts in `assets/fixtures/demo_accounts.json`, or tap "Demo student" / "Demo teacher" on the login screen. Accounts you register in demo mode are kept in memory only, so they're gone after a reload, but the signed-in session stays.
