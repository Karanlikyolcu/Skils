# Frontend Engineering

## Component structure

- Organize by feature, not by type. `features/checkout/` owns its components, hooks, types, and API calls. A change to checkout stays in one folder and can be deleted as a unit.
- Route-level components compose feature components. Feature components compose presentational components.
- Presentational components take props and render. Container components fetch and orchestrate. This separation makes the rendering path testable without mocking the network.

```text
src/
├── app/          # providers, router, global styles, error boundaries
├── features/     # one folder per feature
│   └── checkout/
│       ├── components/
│       ├── hooks/
│       ├── api.ts
│       └── types.ts
├── shared/       # ui primitives, hooks, utils, http client
└── lib/          # third-party wrappers and configuration
```

Dependency direction: `app -> features -> shared`. `shared` must not import from `features`. `features` must not import from each other except through a deliberate public API.

## State management

Sort state into three categories before choosing where it lives:

| Kind | Where | Examples |
|------|-------|----------|
| Server state | Server cache | User, orders, permissions |
| Global client state | Store (only if truly global) | Theme, auth session, feature flags |
| Local UI state | Component | Dialog open, tab, input value |

- Server state and client state have different lifecycles. Mixing them in one store causes refetch loops and lost updates.
- Prefer the platform's server-state cache (React Query, SWR, RTK Query, Apollo) over hand-rolled `useEffect` + `useState` fetching. Hand-rolled fetching misses deduplication, cancellation, retries, staleness, and cache invalidation.
- Derive, do not duplicate. `const active = items.filter(i => i.active)` beats storing `active` alongside `items`.
- Lift state only to the lowest common ancestor. Higher than that makes every component re-render for unrelated reasons.
- Do not put high-frequency values (mouse position, scroll offset, animation frame) in a global store. Subscribe to them locally with a ref or a dedicated hook.

## Data fetching

- The cache owns freshness. Configure stale time and refetch triggers per query type, not globally.
- Invalidate by key prefix on mutation, so related lists refresh together.
- Show the previous data while refetching (keep previous data) to avoid a flash of empty state.
- Cancel in-flight requests when the component unmounts or the query key changes.
- Disable retry for 4xx (except 408 and 429). Retrying a 400 just wastes time.
- Handle out-of-order responses: a slow earlier request must not overwrite a fast later one. The query library handles this by key; do not defeat it.

## Forms

- Use one schema for validation, shared with the server when possible.
- Client validation is for feedback, not security. The server revalidates everything.
- Track: value, touched, dirty, error, submitting. Each field needs all five.
- Validate on blur for most fields, on change for already-errored fields, and on submit for the whole form.
- Do not clear a server error while the user is fixing that field. Clear it on the next successful submit or when the field becomes valid.
- Preserve input on a failed submit. Never lose a long form.
- Prevent double submission: disable the submit button while the request is in flight, and make the handler idempotent.
- Submitting is async: handle the pending state, the success state, and the failure state.

## Rendering performance

- Measure before optimizing. The React DevTools profiler and browser performance panel answer "why did this re-render" in seconds.
- **Memoization**: `memo`, `useMemo`, `useCallback` are not free. Apply them where the measurement shows a cost, not preemptively. An unstable prop (a new object or arrow function every render) defeats `memo` entirely.
- **Stable keys**: use a stable ID, never the array index, for lists that can reorder.
- **Virtualization**: render only what is visible for lists over ~100 rows.
- **Code splitting**: split by route. Load heavy components (editor, chart, map) lazily.
- **Images**: serve the right size and format, use `srcset`, set explicit dimensions to avoid layout shift, lazy-load below the fold.
- **Avoid layout thrash**: do not interleave reads (`offsetHeight`) and writes (`style.height`) in a loop. Batch reads, then writes.
- **Debounce** expensive work triggered by input; **throttle** scroll and resize handlers.

## Accessibility

- Semantic elements first: `button` for actions, `a` for navigation, `label` for form fields, `nav`, `main`, `header`, `ul`/`li`.
- Every input has an associated `<label>`. Placeholder text is not a label.
- Visible focus indicators. Never `outline: none` without a replacement.
- Keyboard: everything reachable and operable by keyboard. Modals trap focus and close on Escape. Skip-to-content link.
- ARIA only when semantics cannot express it. The first rule of ARIA is not to use ARIA.
- Live regions for async updates (search results, save confirmation).
- Images need alt text; decorative images need `alt=""`.
- Contrast 4.5:1 for body text, 3:1 for large text and meaningful UI shapes.
- Respect `prefers-reduced-motion`.

## Error handling in the UI

- Error boundaries at the route level, so one broken widget does not blank the app.
- Show a human message and a retry. Never a raw error object or a stack trace.
- Distinguish "you need to log in" from "something failed" and from "no results".
- Log the underlying error to telemetry with a request ID; show the user the friendly message.
- Fallback UI for every async component: skeleton (loading), empty state (no data), error state (failed), content.

## State of every async view

| State | Requirement |
|-------|-------------|
| Loading | Skeleton matching the final layout, no layout shift |
| Empty | Why it is empty and what to do next |
| Error | Message, retry, and a way to get help |
| Partial | Show what loaded, offer to retry the rest |
| Success | Content, and confirmation for mutations |

## Forms of state that people get wrong

- The URL is state. Filters, tabs, pagination, and the opened item belong in the query string so the view is shareable and the back button works.
- Optimistic updates need a rollback path. If the mutation fails, restore the previous state and tell the user.
- Avoid state derived during render from a value that changes mid-render. Use an effect, a derived value, or `useSyncExternalStore`.
- Do not mutate state objects in place. Produce a new object.

## Browser APIs worth knowing

- `IntersectionObserver` for lazy loading and infinite scroll; better than scroll listeners.
- `ResizeObserver` for element size changes.
- `MutationObserver` for DOM changes.
- `PerformanceObserver` for real user metrics.
- The Navigation API or the History API for routing and scroll restoration.
- `localStorage` for small, non-sensitive preferences only. It is synchronous, small (about 5 MB), and shared across tabs.

## TypeScript practices

- `unknown` at the boundaries, narrowed before use. Never `any` in application code.
- Discriminated unions over optional fields for mutually exclusive states.
- `as` is a cast, not a conversion. Prefer a real check or a schema parse.
- Validate external data (API responses, URL params, localStorage) with a schema at runtime. Types from the server do not exist at runtime.
- Avoid `!` non-null assertions; they convert a compile error into a runtime crash.
