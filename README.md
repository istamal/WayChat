# waychat

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Secrets and env

This project expects secrets and service config via env vars at build time using
`--dart-define` or `--dart-define-from-file`. For local dev, it also loads
`.env` at runtime via `flutter_dotenv` (bundled as an asset).

Example:

```bash
flutter run --dart-define-from-file=.env
```

Required:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_HOST`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_MESSAGING_SENDER_ID`

Optional:
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_AUTH_DOMAIN` (web/windows)
- `FIREBASE_MEASUREMENT_ID` (web/windows)
- `FIREBASE_IOS_BUNDLE_ID`
- `FIREBASE_API_KEY` + `FIREBASE_APP_ID` (fallback for all platforms)
- `FIREBASE_*_API_KEY` / `FIREBASE_*_APP_ID` (platform overrides)

Platform config files are not tracked:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`

Use the `*.example` files as templates.
