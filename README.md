# patients

Flutter client for **My Health Record** (Government of Punjab patient experience): CNIC/OTP sign-in, medical records, appointments, ID scanning, PDF/printing, and theming.

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

By default the app talks to **production**:

| Service | URL |
|---------|-----|
| EMR (HMIS_Prod) | `https://hmis-api.pshealthpunjab.gov.pk` |
| Auth (OTP / lookup) | `https://hmis-authapi.pshealthpunjab.gov.pk` |

### Local backends

```bash
flutter run --dart-define=USE_LOCAL_API=true
```

Or point at specific hosts:

```bash
flutter run \
  --dart-define=EMR_BASE_URL=https://YOUR_HOST:7287 \
  --dart-define=AUTH_SERVER_BASE_URL=http://YOUR_HOST:5045
```

- **Android emulator + local API:** loopback is `10.0.2.2` (set automatically with `USE_LOCAL_API`).
- **Physical device + local API:** use your machine’s LAN IP in the dart-defines.
- **Chrome / Flutter web → production:** production must allow your web origin in CORS.

### Release build (Android)

```bash
flutter build appbundle --release --obfuscate \
  --split-debug-info=build/debug-info
```

Release always uses the production hosts unless you pass explicit
`EMR_BASE_URL` / `AUTH_SERVER_BASE_URL` dart-defines. See
`docs/PRODUCTION_RELEASE.md` for signed Play Store releases.

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
