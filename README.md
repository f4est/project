# FitPilot

FitPilot is a mobile Flutter application for intelligent support of home workouts with personalized recommendations, live movement tracking, and wearable data synchronization.

The project is focused on Android/iOS and is prepared as a diploma-level product concept with practical AI-driven training support.

## Product Scope

FitPilot provides:
- personalized onboarding (age, height, weight, lifestyle, occupation, goal)
- adaptive weekly workout planning
- live camera-based technique tracking (on-device)
- post-workout feedback loop for recommendation updates
- wearable telemetry integration (Health Connect / Apple Health bridge model)
- profile, analytics, workouts, and device synchronization screens
- local settings for voice, theme, font scale, privacy, and sync behavior

## AI Approach (No External AI APIs)

FitPilot does not call external AI model APIs for training logic.

Core intelligence is implemented inside the app:
- recommendation engine for adaptive workout plans
- progress analyzer for consistency/load trends
- on-device pose-based live control with Google ML Kit Pose Detection
- rule-based quality scoring and repetition counting with anti-noise logic

## Tech Stack

- Flutter / Dart
- Firebase Authentication
- Cloud Firestore
- camera
- google_mlkit_pose_detection
- flutter_tts
- health
- workmanager
- shared_preferences

## Architecture

The codebase follows clean architecture boundaries:
- `domain`: entities, repositories contracts, services, use cases
- `data`: Firebase gateways, stores, repository implementations
- `presentation`: controllers, pages, UI state
- `core` / `background`: theming, time sync, scheduled workers

Testing baseline:
- unit tests for recommendation and live analyzer logic
- widget test for core onboarding/auth flow

## Platform Requirements

- Flutter SDK compatible with `sdk: ^3.10.7`
- Android `minSdk = 26`
- iOS deployment target configured in Xcode project

## Project Setup

1. Install dependencies:

```bash
flutter pub get
```

2. Configure Firebase:
- Android: place `google-services.json` at `android/app/google-services.json`
- iOS: place `GoogleService-Info.plist` at `ios/Runner/GoogleService-Info.plist`

3. Run app:

```bash
flutter run
```

## Health Data Integration

On Android, FitPilot works through Health Connect.

Expected user flow:
1. Install/enable Health Connect.
2. Connect wearable app (for example Zepp, Garmin, Huawei Health) to Health Connect.
3. Connect FitPilot in the Devices screen.
4. Grant read permissions for metrics (steps, calories, heart rate, sleep, SpO2, etc.).
5. Sync in FitPilot Devices dashboard.

Notes:
- availability of metrics depends on wearable vendor export policy
- some sources can export only a subset of data

## Live Camera Tracking Notes

For stable detection:
- keep full body or required movement zone in frame
- use stable camera placement (tripod/surface is preferred)
- maintain sufficient lighting
- keep distance appropriate for selected exercise

The app includes:
- orientation-safe image rotation handling
- camera configuration fallbacks for broad Android device support
- anti-noise repetition detection rules
- user-facing error hints and voice prompts

## Release Build

Android APK/AAB:

```bash
flutter build appbundle --release
```

iOS IPA (from macOS/Xcode environment):

```bash
flutter build ipa --release
```

Before production release:
- replace debug signing with release signing credentials
- verify Firebase production project/environment
- validate privacy policy and store listing requirements
- verify permission disclosures (camera, health data, background sync)

## Compliance and Safety

FitPilot is a fitness support application and not a medical device.
Recommendations and technique hints are informational and should not replace professional medical advice.

## Current Repository State

This repository contains active development history and staged feature evolution.
If you need a strict release branch, create one from current `main` and run final QA and store compliance checks before submission.

## License

Internal / educational use unless a separate license file is added.

