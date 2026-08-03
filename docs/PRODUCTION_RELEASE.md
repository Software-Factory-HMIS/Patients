# Patients Android production release

## Repository placement

This file and `.github/workflows/ci.yml` assume `Patients/` is the Git repository
root. GitHub only loads workflows from the repository root's `.github/workflows/`.
If the enclosing HMIS directory later becomes the repository, move the workflow
there and set its working directory (and artifact/signing paths) to `Patients/`.

## One-time production setup

1. Create a protected GitHub environment named `production`, requiring release
   approval. Add environment variables `EMR_BASE_URL` and
   `AUTH_SERVER_BASE_URL`; both must be public HTTPS origins without a trailing
   path. `--dart-define` values are recoverable from the app, so never put
   credentials in them.
2. Generate and escrow the Android upload key outside source control. Add these
   environment secrets:
   - `ANDROID_KEYSTORE_BASE64`: base64 of the binary JKS file
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
   - `ANDROID_STORE_PASSWORD`

   Keep the original keystore and passwords in the approved secrets vault with
   recovery ownership documented. The workflow creates `android/key.properties`
   only on its ephemeral runner, validates the key, and fails before Gradle when
   any signing value is absent. It never intentionally invokes debug signing.
3. Before the first release, confirm both backends are production-ready: valid
   public TLS chains, deployed database migrations, matching API contracts,
   compatible JWT issuer/audience/signing configuration, operational OTP
   provider, rate limits, monitoring, and redacted logs. Test the URLs from the
   same network classes used by patients.
4. Confirm the approved privacy policy still requires Android backups to remain
   disabled. The manifest denies backup and profile photos use cache-only
   storage; verify credentials, records, images, and generated documents do not
   enter platform or vendor backup services on the release devices.

## Build and verify

1. Update `pubspec.yaml` to a unique, monotonically increasing build number.
2. Merge only after CI reports zero analyzer errors and `flutter test` passes.
3. Run the workflow manually from the intended commit, or push an approved
   `v*` tag. The protected environment supplies URLs and signing material.
4. Download `patients-android-<run-id>`. The bundle is built with
   `--obfuscate` and `--split-debug-info`; archive `build/debug-info` in
   access-controlled release storage keyed by version/build. Losing it prevents
   useful symbolication.
5. Verify the downloaded AAB checksum against `app-release.aab.sha256`. Confirm
   the signer certificate matches the registered upload certificate, and inspect
   package ID `pk.gov.pshealthpunjab.hmis.patients`, version name/code,
   permissions, and supported ABIs in Play Console (or `bundletool`) before
   promotion. The workflow also checks that the AAB signer matches the supplied
   keystore.

## Physical-device smoke test

Install a Play internal-testing build on at least one representative arm64
device and one lowest-supported Android version. Using non-production test
patients, verify:

- cold start, English/Urdu layout, sign-in, OTP delivery, expiry, and logout;
- patient lookup, records, prescriptions/reports, appointment booking, and PDFs;
- camera/image selection and location permission denial/approval;
- slow/offline recovery, expired sessions, and redacted crash/log output;
- app data is removed on logout/uninstall as required by the approved policy.

Record device/OS, app version/code, backend release, tester, and evidence. Do not
promote when a release build contacts any non-production origin.

## Rollout and rollback

Use a staged Play rollout and watch authentication, OTP, API error, crash, and
latency signals. Stop the rollout on regression. Roll back by halting the bad
release and publishing the last known-good source as a new bundle with a higher
version code; Play cannot downgrade an installed version code. Keep backend
changes backward-compatible through the rollback window, or execute the tested
backend rollback first. Preserve the AAB, checksum, source commit, workflow run,
signer fingerprint, symbols, configuration URLs, approvals, and smoke-test
record for every production release.
