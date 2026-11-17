# Science Signal

Activity 16 Class B science quiz for Myles Miller, undergraduate.

## App

Sign in with an authorized Firebase test account, answer five medium Science & Nature True/False questions, review every selection, and save the completed round. The app only reports **Cloud verified** after a matching server-only Firestore read returns a resolved timestamp with no pending writes. Acknowledged writes and failed verification stay separate.

## Setup

- Flutter and Dart versions are recorded in `evidence/toolchain.txt`.
- Firebase project: `science-signal-16-myles`; Android application: `com.example.science_signal`.
- Cloud Firestore Standard Native mode, location `us-east1`, production owner-only rules in `firestore.rules`.
- Enable Email/Password authentication and create two fictional test accounts in Firebase Authentication. Request existing authorized test access through a private course channel; never publish passwords or tokens.
- Run `flutter pub get`, `flutterfire configure --project=science-signal-16-myles --platforms=android`, and `firebase deploy --only firestore:rules --project science-signal-16-myles` under an authorized project account.
- Client Firebase configuration identifies the project; it is not an admin credential. No service-account key belongs in Flutter.

## Run and verify

Use `flutter run` or `flutter build apk --release`. The release build excludes fault controls unless explicitly compiled with `ENABLE_TEST_HOOKS=true`; the submitted APK uses the default false value.

`flutter test` checks URI decoding and invalid model rejection. `integration_test/acceptance_test.dart` runs T01-T12 against a real cloud project. Supply TEST_EMAIL_A, TEST_PASSWORD_A, TEST_EMAIL_B, TEST_PASSWORD_B and ENABLE_TEST_HOOKS in a private temporary JSON file outside the repository, then run:

```
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/acceptance_test.dart --dart-define-from-file=PRIVATE_FILE -d ANDROID_DEVICE
```

The Android test uses labeled HTTP fixtures for invalid-response and deterministic scoring cases. T02 fetches the exact live endpoint; cloud checks use deployed Firestore, not a Firestore emulator. Permission, network-service and quota verification faults use a one-shot development-only repository hook after a real commit. T10/T11 exercise actual deployed security rules.

## Restart retrieval

After saving, retain the displayed round ID privately. Close and relaunch the app while online, sign in as the same authorized test user if prompted, open **Retrieve a saved round**, enter that exact ID, and choose **Read from server**. This retrieves the existing document without answering another round. The expected display includes the score, server timestamp, cache=false and pending=false. A missing record or denied read must never be reported as verified.

## Data and recovery

Path: `users/{authenticatedUid}/attempts/{roundId}`. Exactly six fields: schemaVersion=1, variant=B, categoryId=17, questionCount=5, correctCount=0..5, submittedAt=server timestamp. Attempts are immutable. Transactions read before creating; identical retries reuse the record and mismatched scores report a collision. IDs are generated outside the retryable transaction.

A UI timeout does not cancel Firestore. Unknown saves preserve the ID, block replay/sign-out, and reconcile through a server read before another write. Pending operations are tracked to prevent overlapping retries. Owner-only rules enforce access and shape, but cannot establish that a client honestly earned its score; server-authoritative scoring is a future improvement.

## Assistance

Codex assisted with implementation, writing and automated verification. Evidence describes actual executed tests and explicitly labels injected faults and fixtures. No teammate contributions or peer observations are claimed.

## Verified build

Flutter 3.47.2, Dart 3.13.2; Android 17 AdaptiveFocus Pixel 4 emulator. Verified implementation and test commit: `ce0dd90a7b9d7421662cfe9be22c9b2df63c63d2`. The packaging commit adds these results without changing the app. Use `git rev-parse HEAD` for the current packaging revision.

All T01-T12 checks passed against deployed cloud services where required. A separate fresh-process test passed same-ID retrieval and confirmed exactly two correct selections produce 2/5. Static analysis found no issues and both model tests passed. Release APK 1.0.0+1 built, installed successfully, and opened its sign-in screen on Android 17. The release omits test credentials and fault controls. APK SHA256: `9b7ebc61306d9d7d134a82ed5d696e8021efcfa74bd59370f1e999995e056b38`.
