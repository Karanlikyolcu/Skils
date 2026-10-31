---
name: Application Developer
description: Use for building applications - mobile, desktop, and packaged web apps. Covers layered app architecture, state management, offline-first storage and sync, navigation, UI implementation and design systems, accessibility, startup and runtime performance, data persistence, push notifications, background work, and build, signing, and release pipelines.
metadata:
  opencode/autoinvoke: true
license: MIT
---

# Application Developer

An application is judged on the first ten seconds: does it open fast, does it show something meaningful, does it feel solid under the thumb. Then it is judged on whether it still works on a bad network, in the background, on an old device, and after the app is killed and relaunched.

## 1. Architecture with enforced boundaries

Use a layered or feature-first structure, and make illegal dependencies impossible to write.

```
presentation  ->  domain  <-  data
   (UI)          (rules)     (network, db, prefs)
```

- **Domain** holds the rules and models. It knows nothing about UI, HTTP, or the database. This is what makes it testable without mocks.
- **Data** implements the interfaces the domain defines. Repositories, API clients, local storage.
- **Presentation** renders state and dispatches user intent. It contains no business rules.

Rules:

- Dependencies point inward. Presentation may know domain. Domain must not know presentation.
- Feature-first over layer-first: group by feature (`feature/checkout/`) so one feature's code lives in one place and can be deleted as a unit.
- The domain defines what it needs (`interface PaymentGateway`); the data layer provides the implementation. Do not import a concrete HTTP client into the domain.
- Do not put logic in a widget callback. Move it to the domain or a controller, then call it.
- Keep one-way data flow: events in, state out, view from state.

## 2. State management

Separate the three kinds of state; they have different lifetimes and different sources of truth.

| State | Lives in | Examples |
| ----- | -------- | -------- |
| Server state | Cache with invalidation | Profile, list of orders |
| Persisted local state | Database / preferences | Draft, settings, cached rows |
| Ephemeral UI state | In-memory, per screen | Panel open, scroll position, text field |

Rules:

- One source of truth per piece of state. Two copies that must be kept in sync will drift.
- Derive instead of duplicating: a filtered list is computed from the source list, not stored alongside it.
- Unidirectional flow: the view emits an intent, a controller handles it, the resulting state flows back to the view.
- Do not put frequently changing values (scroll offset, animation progress, keystrokes) into a broad app-wide state container. Scope them to the smallest component that owns them.
- Persist only what must survive a restart, and version the persisted schema.

## 3. Offline-first and sync

If the app has any network dependency, it will be used offline. Design for it.

- Local database is the source of truth for the UI. The network is a sync source, not the read path.
- Every remote write becomes a local write plus an outbox entry, applied optimistically to the UI.
- The outbox is durable: it survives app kill, reboot, and network loss. Sync retries with exponential backoff and jitter.
- Conflict resolution must be explicit. Choose a rule (last-write-wins per field, server-wins, or a merge) and apply it consistently. Silent last-write-wins loses user data; make it a deliberate decision.
- Show sync state honestly: pending, synced, failed, and a manual retry. Never claim data is saved when it is only queued.
- Handle the ordering problem: use a monotonic version or a logical clock per record so a stale response cannot overwrite a newer local edit.
- Test with the network off, slow, flaky, and switching between offline and online mid-operation.

## 4. Persistence

- Choose the right store: key-value for settings and small flags, SQLite or an equivalent for relational and queryable data, files for blobs.
- Every persisted model needs a schema version and a migration path from the previous version.
- Encrypt sensitive local data at rest, and keep the key in the platform keystore, not next to the data.
- Do not store large blobs in preferences. Store the metadata in SQLite and the bytes on disk.
- Handle a full disk and a corrupt database gracefully: detect, recover, and tell the user.
- Never block the main thread with disk or network IO. Use background executors/coroutines/isolates.

## 5. UI implementation

- Follow the platform conventions, not web conventions transplanted into a native app.
- Build the four states for every data view: loading, empty, error, content. Skeletons over spinners for content that has a known shape.
- Keep touch targets at least 44x44 dp / 48x48 px, with spacing around them.
- Design for one-handed use, thumb reach, and short sessions.
- Handle safe areas, notches, gesture bars, keyboard overlap, and rotation.
- Support dynamic type and large fonts without truncation or clipping. Test at the largest accessibility size.
- Dark mode is a separate design pass, not an inverted palette.
- Animations must respect the platform's reduced-motion setting and never block input.
- Use a design system: shared spacing scale, type scale, colors, and components. One place to change.

## 6. Accessibility

- Every interactive element has a label. Icons that carry meaning need an accessibility label.
- Support screen readers on every platform: correct roles, hints, and value changes announced.
- Support keyboard navigation and focus order on desktop and web.
- Meet contrast ratios: 4.5:1 for body text, 3:1 for large text and UI boundaries.
- Do not rely on color alone to convey state. Add an icon, shape, or text.
- Respect the reduced-motion and bold-text system settings.
- Test with the platform accessibility inspector before shipping.

## 7. Performance

**Startup**: show a usable screen fast. Defer non-essential initialization. Target a time-to-meaningful-content budget (commonly under 1.5 s on mid-range devices). Measure cold start, not warm start.

**Runtime**:
- Keep the main thread clear. IO, JSON parsing, and image decoding belong off it.
- Batch or defer UI updates; a frame with 200 individual state updates is a dropped frame.
- Virtualize long lists. Never render 10,000 rows.
- Recycle views and images. Downsample images to the size actually displayed.
- Avoid allocating in hot paths; reuse buffers and objects.
- Watch for main-thread work triggered by background events, and for work that continues when the app is not visible.

**Battery and network**:
- Batch analytics and telemetry.
- Respect the platform background limits; do not assume a long-running background task is possible.
- Sync on meaningful triggers (app open, user action, connectivity change), not on a tight timer.

## 8. Background work

- The platform limits background execution strictly. Design for the app being suspended at any moment.
- Persist in-progress state so work can resume after a kill.
- Make background tasks idempotent. A retried task must not duplicate its effects.
- Make long operations resumable in steps with checkpoints.
- Do not assume timers fire on time. Re-check elapsed time inside the work itself.

## 9. Notifications and deep links

- Notification payloads are untrusted input. Validate and sanitize before acting on them.
- Deep links are untrusted. Verify the scheme, host, and path, and never let a link grant access the user does not have.
- Handle the case where the app was killed and is launched straight from a notification.
- Deep link into the correct screen with the right entity loaded, and handle a missing or deleted entity gracefully.
- Request notification permission at a sensible moment, with context, not on first launch.

## 10. Build, sign, release

- Keep release builds reproducible: pinned dependencies, locked versions, deterministic inputs.
- Never commit signing keys, keystores, or service credentials. Secure them in CI or a secret manager.
- Separate build flavors and environments: dev, staging, production. Endpoints, keys, and feature flags must not be switched by hand.
- Version monotonically: `major.minor.patch`, plus a build number that increases every upload.
- Increment the version for every store upload, including rebuilds of the same version.
- Use staged rollout for risky releases, and a remote kill switch for features.
- Verify the release artifact locally before upload: install the built binary and run a smoke test. A CI build that was never run on a device is unverified.
- Write release notes that say what changed for the user, not what changed in the code.

## Supporting files

- `references/architecture.md` - layer and feature structure, dependency rules, DI, module boundaries.
- `references/state-and-data.md` - state taxonomy, offline sync, conflict resolution, persistence, migrations.
- `references/ui-ux.md` - design systems, navigation, lists, forms, empty states, accessibility details.
- `references/app-performance.md` - startup, main thread, memory, battery, image and list handling.
- `references/release.md` - versioning, flavors, signing, CI pipelines, staged rollout, crash reporting.
