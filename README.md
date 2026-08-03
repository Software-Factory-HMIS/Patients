# patients

Flutter client for **SehatLink** (Government of Punjab patient experience): CNIC/OTP sign-in, medical records, appointments, ID scanning, PDF/printing, and theming.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install/macos) with Dart **3.9.2+** (see `environment.sdk` in `pubspec.yaml`).
- For iOS: Xcode and CocoaPods as described in the Flutter docs.
- For Android: Android Studio / SDK and an emulator or device.

Verify your install:

```bash
flutter doctor -v
```

## Setup

From the repository root:

```bash
cd Patients
flutter pub get
flutter analyze
```

If builds act stale:

```bash
flutter clean && flutter pub get
```

## Run

```bash
flutter devices
flutter run
```

Override the EMR API base URL (defaults are in `lib/utils/api_config.dart`):

```bash
flutter run --dart-define=EMR_BASE_URL=https://YOUR_HOST:7287
```

- **Android emulator:** default base URL uses `10.0.2.2` to reach the host machine.
- **Physical devices:** use your machine’s LAN IP in `EMR_BASE_URL`.

## Project layout

| Area | Path |
|------|------|
| Screens & flows | `lib/screens/` |
| Auth, session, theme | `lib/services/` |
| API client & helpers | `lib/utils/` |
| Shared widgets | `lib/widgets/` |

## Further reading

- [Flutter documentation](https://docs.flutter.dev/)
- UX/feature notes: `FULL_REVAMP_FEATURES.md`
- DevTools / Chrome issues: `TROUBLESHOOTING_DEVTOOLS_CONNECTION.md`, `TROUBLESHOOTING_CHROME_CONNECTION.md`
