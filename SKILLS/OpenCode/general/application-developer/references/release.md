# Release Pipeline

## Versioning

- `major.minor.patch` plus a monotonically increasing build number.
- Increment the build number for every upload, including a rebuild of the same version.
- Define the meaning:
  - major: breaking change to a public API or a required migration
  - minor: new functionality, backward compatible
  - patch: a fix, backward compatible
- Write the version from one source in the build configuration. Never hardcode it per flavor.
- Tag the release commit: `v1.4.2`. Tag releases, not every commit.

## Build variants

```text
flavor: dev      -> dev API,       verbose logs, debug signing, mock data
flavor: staging  -> staging API,   sanitized logs, release signing, test data
flavor: prod     -> prod API,      no verbose logs, release signing

buildType: debug   -> debuggable, no minification, dev tools
buildType: release -> minified, shrunk, optimized
```

- Endpoints, API keys, and feature flags must never be switched by editing code at build time by hand.
- The build type determines the signing key; the flavor determines the environment.
- Release and debug builds must behave identically apart from the tooling. Debug-only `if` branches that change logic are a bug source.

## Signing and secrets

- Signing keys (keystore, P12, provisioning profile) live in the CI secret store or an HSM. Never in the repository, never in an artifact.
- The CI job that signs has access to the key and nothing else.
- Restrict release permissions to a small group, and require a review for production.
- Back up the upload key. Losing it means losing the listing.
- Use Play App Signing / managed signing so the upload key is not the app key.
- Rotate any signing material that has been exposed, and update the store records accordingly.

## CI pipeline

```text
install (locked deps)
  -> format check
  -> lint
  -> type check
  -> unit tests
  -> build (unsigned or dev-signed)
  -> integration tests
  -> sign
  -> upload to the store (internal track)
  -> smoke test
```

- Every gate fails the build. A warning that does not fail will be ignored within a month.
- Build from the lockfile. Pin the toolchain version.
- Cache dependencies, not build outputs. A stale cached binary is a mystery bug.
- Produce a reproducible artifact: the same source produces the same binary.
- Run the expensive steps last, so a lint failure does not cost a full build.
- Store the mapping file (ProGuard/R8 mapping, dSYM) as a build artifact. Without it, crash reports are unreadable.

## Store submission

**Android (Google Play)**

- Version code increments by at least 1 for every upload.
- Upload an AAB (app bundle).
- Provide the Play Signing configuration and a release key backup.
- Complete the Data Safety form to match the actual behavior.
- Staged rollout: start at 5-10%, then widen.
- Pre-launch report for crash and ANR detection.

**iOS (App Store Connect)**

- Build number (CFBundleVersion) increments for every upload.
- Upload a signed IPA or use Xcode Cloud / the Transporter.
- Provide App Privacy details (nutrition label) matching reality.
- Phased release (1%, 2%, 5%, 10%, 20%, 50%, 100%) with an automatic halt on a crash-rate threshold.
- Export compliance is answered at every upload.

**Content**

- Screenshots at every required device size, from the real app.
- A release description that says what changed for the user.
- Review notes for anything requiring an account or special setup; provide demo credentials.
- A support URL and a privacy policy URL that resolve.

## Testing the release build

- Install the built artifact on a real device. Do not trust the CI build.
- Run a smoke test: launch, sign in, complete the core flow, check the backend receives data.
- Test on the lowest supported OS version and on the lowest supported device.
- Test with the network off, on a slow network, and with a small disk.
- Verify the production endpoints and keys, and that debug logging is off.
- Verify the app icon, launch screen, and app name are the production ones.
- Verify the privacy manifest and permission declarations.

## Rollout and monitoring

| Metric | Watch | Halt if |
|--------|-------|--------|
| Crash-free users | 24 h and 48 h | Below the baseline by a margin |
| ANR rate | Immediately | Spikes |
| Startup time (p90) | 24 h | Regression |
| Key business metric | 24 h | Drops versus the control |

- Halt the rollout automatically when the crash rate exceeds a threshold.
- Keep a remote kill switch for a risky feature. A flag that requires a release to turn off is not a kill switch.
- Every rollout needs an owner and a watch window.

## Hotfix path

- Keep a release branch that only receives fixes, so a hotfix is a cherry-pick plus a version bump.
- Know the exact steps: bump the version, run the pipeline, upload, wait for review, monitor.
- A hotfix still needs a test. If the fix is one line and has a one-line test, the release takes an hour, not a day.
- Communicate the hotfix to the user in the release notes.

## Anti-patterns

- Manually editing a version string in several files.
- Signing keys in the repository or in a CI log.
- Uploading the same build number twice.
- Shipping without the mapping file.
- Testing only the debug build.
- A release process that requires one person with undocumented steps.
- No kill switch, so a bad release can only be fixed by removing it from the store, which takes hours.
