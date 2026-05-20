# Evolo

Evolo is a Flutter mobile app for visually documenting evolution over time. The product is local-first for now: users can create projects, capture photos, align new captures with the previous image as a ghost frame, review a timeline, and preview a replay.

## Architecture

The app is organized feature-first with a small shared core:

- `lib/core`: theme, routing, constants, services, and reusable widgets.
- `lib/features/onboarding`: Portuguese-first entry experience.
- `lib/features/projects`: project and capture models, local persistence, project list.
- `lib/features/capture`: fullscreen rear-camera capture with previous-image overlay and opacity control.
- `lib/features/timeline`: visual capture history foundation.
- `lib/features/replay`: local cinematic replay preview foundation.

State is managed with Riverpod. Routing uses GoRouter. Local persistence currently uses `shared_preferences` for project metadata and app documents storage for captured media.

## Product Foundations

- Dark-mode-first cinematic theme inspired by `DESIGN.md`.
- Portuguese UI strings centralized in `AppStrings` for a future migration to generated localization.
- Optional Supabase bootstrap via compile-time environment variables.
- Optional PostHog event tracking with a typed event list.
- Optional Sentry error capture for Flutter, async, camera, and storage failures.
- Local-first architecture that can later add auth, cloud sync, entitlements, and Stripe-backed subscriptions without forcing signup into the first session.

## Environment

Optional values can be provided with `--dart-define`:

```bash
--dart-define=SENTRY_DSN=...
--dart-define=POSTHOG_API_KEY=...
--dart-define=POSTHOG_HOST=https://us.i.posthog.com
--dart-define=SUPABASE_URL=...
--dart-define=SUPABASE_ANON_KEY=...
--dart-define=APP_ENV=development
```

## Commands

This project uses the local Flutter SDK configured in `android/local.properties`:

```powershell
C:\Users\rodri\flutter\bin\flutter.bat pub get
C:\Users\rodri\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib test
C:\Users\rodri\flutter\bin\flutter.bat test
```

If plugin symlink generation fails on Windows, enable Developer Mode in Windows settings.
