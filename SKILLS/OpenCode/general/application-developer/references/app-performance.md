# Performance and Release

## Startup

Cold start is the first impression and the biggest single metric in store reviews.

- Target: meaningful content on screen in under 1.5 s on a mid-range device. Under 2 s is acceptable; more is a review risk.
- Measure cold start (process not running), not warm start.
- Defer non-essential work: analytics, A/B testing, ad SDKs, non-critical network calls, and heavy UI behind a post-first-frame callback.
- Show a launch screen immediately, matching the app icon and the eventual background color, so there is no flash.
- Initialize only what the first screen needs. Lazy-initialize the rest.
- Do not block the main thread with disk or database work at launch. Use a splash screen while it runs.
- Avoid a splash screen that shows for a fixed minimum duration; show it only until the content is ready.
- Measure the breakdown: process start, framework init, dependency injection graph, first screen render, first data.

## Runtime performance

**Main thread**

- Keep it free of IO, JSON parsing, image decoding, and database queries.
- Use background executors, coroutines on IO dispatchers, or isolate-based work.
- Batch UI updates: 200 individual state emissions cause 200 recompositions or 200 redraws.

**Lists**

- Virtualize. Only render what is visible.
- Use stable keys and a proper diffing mechanism so a cell is not fully rebuilt on every update.
- Keep item views shallow.
- Prefetch a few items ahead of the scroll direction.

**Images**

- Decode to the displayed size, not the source size. A 4000px photo in a 200px slot wastes tens of megabytes.
- Use an image cache with a memory limit and a disk cache.
- Downsample during decode.
- Compress the format (WebP, HEIC) and serve the right density variant.
- Lazy-load below the fold.

**Memory**

- Watch the memory high-water mark. A spike that is never released causes a kill on low-memory devices.
- Release large buffers when the screen goes away.
- Trim memory caches on a memory-pressure signal (`onTrimMemory`, `didReceiveMemoryWarning`).
- Watch for leaks: a retained activity, a static reference to a context, a listener never removed, a closure capturing a view.

**Battery**

- Batch network requests and analytics.
- Respect the platform background limits.
- Sync on triggers, not on a timer.
- Avoid polling. Use push or a push-triggered fetch.
- Stop animations when the app is not visible.

**Animation**

- Animate transform and opacity, not layout.
- Use the platform's animation system so it runs off the UI thread where possible.
- Avoid animating during a list scroll; it causes dropped frames.

## Build and release

**Versioning**

- `major.minor.patch` plus a monotonically increasing build number.
- Increment the build number for every upload, including a rebuild of the same version. Stores reject duplicates.
- Write the version from a single source (the build config), not from a hardcoded string in each flavor.

**Build flavors**

```text
dev      -> dev API, verbose logging, mock data, debug signing
staging  -> staging API, sanitized logs, no analytics
prod     -> prod API, no verbose logs, release signing
```

- Endpoints, keys, and feature flags must never be switched by hand in code.
- The build type determines the signing key, the flavor determines the environment.
- Debug and release behaviors differ: no debug-only code paths that change logic in release.

**Signing**

- Signing keys live in CI or a secret manager. Never in the repository.
- Restrict who can sign, and require two-person review for a production release.
- Back up the key securely. Losing it means losing the app listing.
- Use Play App Signing or the iOS provisioning profile managed by the platform so the upload key is not the app key.

**CI pipeline**

```text
lint -> type check -> unit tests -> build -> integration tests -> sign -> upload -> smoke test
```

- Fail the pipeline on a lint or type error. Do not let it warn.
- Build from the lockfile, with pinned tool versions.
- Cache dependencies, but never cache a stale build output.
- Produce a reproducible artifact: the same commit produces the same binary.
- Run the full test suite before signing, not after.

**Store submission**

- Screenshots at the required sizes and device classes, showing the real app.
- A privacy policy URL and a data safety form that matches the actual behavior.
- An app description in the store language.
- Review notes for anything that needs explaining (login requirements, demo accounts).
- Test the release build. A CI build that was never installed and run is unverified.

**Staged rollout**

- Release to a percentage first (1%, 5%, 20%, 100%).
- Watch crash-free sessions, ANR rate, and key metrics before widening.
- Halt the rollout automatically if the crash rate exceeds a threshold.
- Keep a remote kill switch for risky features.

**Crash reporting**

- Collect crashes with symbolication: upload the dSYM or mapping file for every release.
- Group by stack signature, and track the rate over the release, not the absolute count.
- Include a version and build number in every report.
- Do not collect personal data in crash reports. Redact user input from the captured state.
- Set a threshold for what to triage, so the queue stays actionable.

**Hotfixes**

- Prepare a fast path: a signed build, an upload, and a review, in hours not days.
- Keep the release branch stable enough to cherry-pick a one-line fix onto.
- Avoid large refactors close to a release.

## Monitoring after release

- Crash-free users, crash-free sessions, ANR rate.
- Startup time, especially the p90.
- Business metrics that indicate a broken build.
- Watch the first 24 hours after each rollout closely.

## Pre-release checklist

- [ ] Release build installs and runs on a real device
- [ ] Version and build number incremented
- [ ] Correct flavor: production endpoints and keys
- [ ] No debug logging, no debug menu, no test data
- [ ] Signing keys from the secret manager, not the repo
- [ ] Crash reporting symbolicated
- [ ] ProGuard/R8 or similar minification configured, with the keep rules needed
- [ ] Permissions declared and justified, with a privacy manifest
- [ ] Accessibility pass on the main flows
- [ ] Offline and airplane-mode behavior tested
- [ ] Release notes written for users
- [ ] Staged rollout configured with an automatic halt threshold
