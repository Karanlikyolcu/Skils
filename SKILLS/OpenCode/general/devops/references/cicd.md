# CI/CD Pipelines

## Pipeline shape

```text
trigger -> setup -> lint -> typecheck -> unit -> build -> integration -> package -> deploy -> verify
```

- **Fast gates first.** Lint and typecheck cost seconds. A full E2E suite costs minutes. Order by cost so a cheap failure stops the pipeline early.
- **Every gate fails the build.** A warning that does not fail will be ignored within a month.
- **Build once, promote the same artifact.** Never rebuild between staging and production. What you tested is what ships.
- **Immutable artifacts.** Tag with the commit SHA. A moving tag means you cannot say which code is running.
- **The pipeline is code.** It lives in version control, is reviewed, and is tested.

## Setup stage

- Pin the toolchain: the language version, the package manager, the base image digest.
- Install from the lockfile. A floating dependency range in CI means the build changes without the commit changing.
- Cache dependencies, keyed on the lockfile hash. Never cache the build output; that is what CI is for.
- Fail fast if the lockfile and the manifest disagree.
- Use OIDC or short-lived credentials instead of long-lived secrets in the environment.

## Matrix builds

```yaml
strategy:
  fail-fast: false
  matrix:
    node: [20, 22, 24]
    os: [ubuntu-latest, macos-latest]
```

- `fail-fast: false` so one combination failing does not cancel the others and hide a second failure.
- Only test the combinations that matter. Testing 30 combinations of a library that does not depend on the OS is wasted minutes.
- Exclude combinations that are known not to apply, explicitly, rather than letting them fail.

## Caching and artifacts

- Cache the package manager's download directory, not the installed tree. The installed tree is often not relocatable.
- Key the cache on the lockfile hash plus the OS and architecture. A wrong key produces a corrupt cache, which is worse than no cache.
- Artifacts are for the things you need later: the built binary, the container image, the test report, the mapping file.
- Set a retention period. Artifacts are not a backup.
- Publish the test report as an artifact and as a check, so the PR shows the result.

## Secrets in CI

- Never print a secret. Mask it in the log, and avoid `set -x` around secret usage.
- Scope credentials as narrowly as possible: a read-only token for a job that only needs to read.
- Use OIDC federation with the cloud provider so there is no long-lived key to steal.
- Rotate on a schedule, and immediately after any exposure.
- Scope a write token to a specific environment or path.
- A fork PR must never receive access to production secrets. Gate the job.

## Pull request checks

- Required checks on the branch protection rules, so a PR cannot merge without them.
- Keep the required set small and fast. Every required check is a tax on every PR.
- Run the expensive suite on merge to the main branch or on a schedule, not on every PR.
- Post the test summary as a PR comment, not only in the CI UI, so the reviewer sees it where they work.

## Deployment pipeline

```text
build -> push image -> deploy staging -> smoke test -> deploy prod (canary) -> verify -> widen
```

- The smoke test must exercise the real path: a health check plus one functional request that touches the database.
- The production deploy is automated but gated on a human approval for regulated or high-risk services.
- After the deploy, verify from outside the cluster. An in-cluster check can pass while the ingress is broken.

## Rollback

- The previous artifact must remain deployable. Keep the last N versions.
- A rollback must be a single command, not a reconstruction.
- The data must be backward compatible with the previous version. This is why migrations run as a separate, expand-only step.
- A database migration that cannot be rolled back must be explicitly marked, and the deploy must be planned around it.

## Deployment strategies

| Strategy | Rollback | Cost | Use when |
|----------|----------|------|----------|
| Rolling | Redeploy the previous version | Low | Stateless services |
| Blue/green | Switch traffic back | 2x capacity | Need instant rollback |
| Canary | Disable the flag or route | Low | Want production metrics first |
| Recreate | Redeploy | Brief downtime | Stateful, breaking migration |

## Caching in the build

- Layer Docker builds so the dependency layer caches. Copy the manifest first, install, then copy the source.
- Use BuildKit for parallel stages and better caching.
- Mount the package manager cache in the build (`--mount=type=cache`) instead of copying it into a layer.

## Pipeline anti-patterns

- One giant job that does everything. Split it so a failure is localised and stages can be re-run.
- `continue-on-error: true` on a real gate. It converts a failure into a lie.
- Unpinned action versions (`@main`, `@v3`). Pin by commit SHA.
- Secrets stored in the CI config file.
- A deploy that has never been run from a clean environment.
- Long-running pipelines nobody waits for. If it takes more than 15 minutes, find the bottleneck.
