# Containers

## Dockerfile

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.24-bookworm AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY . .
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/app ./cmd/app

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/app /usr/local/bin/app
USER nonroot:nonroot
ENTRYPOINT ["/usr/local/bin/app"]
```

**Layering**

- Copy the dependency manifest first, install dependencies, then copy the source. The dependency layer is cached until the manifest changes.
- Combine commands with `&&` so a failed step fails the layer instead of being cached as success.
- Clean up in the same layer as the install (`apt-get install ... && rm -rf /var/lib/apt/lists/*`).

**Determinism**

- Pin the base image by digest: `FROM node:22-bookworm-slim@sha256:...`. A tag moves.
- Do not run `apt-get upgrade` in a Dockerfile. It makes builds non-reproducible. Rebuild the base image instead.
- Install from the lockfile, with `--no-install-recommends`.
- Avoid `ADD` with a URL. Use `RUN curl -o ... && checksum`.
- Build from a clean context. Add a `.dockerignore` for `.git`, `node_modules`, build output, and secrets.

**Runtime**

- Multi-stage: the final image contains only the runtime artifact and its dependencies.
- Distroless or `scratch` for static binaries. Alpine for dynamic ones. A minimal base means fewer CVEs and a smaller download.
- A non-root user: `USER nonroot` or an explicit `RUN adduser`.
- No secrets in `ENV`, `ARG`, `COPY`, or a layer. Layers are readable by anyone who pulls the image.
- `ENTRYPOINT` in exec form (`["app"]`), not shell form. Shell form makes the process a shell child, so signals do not reach it.

**Metadata**

```dockerfile
LABEL org.opencontainers.image.title="myapp" \
      org.opencontainers.image.source="https://github.com/org/repo" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.created="2026-01-14T10:00:00Z"
```

## Signals and graceful shutdown

The container must handle `SIGTERM` and exit within the grace period.

- The process must be PID 1 in the container, or it must have an init (`--init`, or `tini`).
- PID 1 does not get default signal handlers, so your app must install them.
- On `SIGTERM`: stop accepting new work, finish in-flight requests, close connections, flush logs, exit 0.
- Set a termination grace period long enough for the drain (`terminationGracePeriodSeconds`).
- If the app cannot drain, the orchestrator sends `SIGKILL` and the request is cut. Design for that.

## Image size

- `docker images` and `docker history` show where the size went.
- A multi-stage build is usually the biggest single win.
- Remove the package manager cache and the build toolchain from the final image.
- `.dockerignore` is often as effective as a multi-stage build.
- Use a shared base layer across services to exploit the layer cache.

## Security

- Run as non-root, and consider `readOnly: true` with a writable tmpfs for `/tmp`.
- Drop all capabilities and add back only what is needed.
- Never mount the Docker socket into a container. It is root on the host.
- Never use `--privileged`.
- Scan images in CI (Trivy, Grype) and gate the deploy.
- Rebuild base images on a schedule so base-image CVEs get patched.
- Do not run untrusted install scripts, and do not pipe a remote script to a shell.

## Runtime configuration

- Configuration comes from the environment or a mounted file, never baked into the image. One image, many environments.
- Validate configuration at startup and exit non-zero with a clear message if it is invalid.
- The image contains the application and nothing that differs per environment.
- Secrets are injected at runtime from a secret manager.

## Health checks

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -fsS http://localhost:8080/healthz || exit 1
```

- The liveness check must be cheap and must not depend on external services. A liveness check that calls the database causes a restart storm when the database is briefly down.
- The readiness check may depend on dependencies, and should fail when the service cannot serve traffic.
- A shell form health check starts a shell each time, which is heavier than it looks.

## Compose

```yaml
services:
  app:
    build: .
    image: registry.example.com/app:1.4.2
    restart: unless-stopped
    env_file: .env
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://localhost:8080/healthz"]
      interval: 30s
    read_only: true
    tmpfs: ["/tmp"]
    security_opt: ["no-new-privileges:true"]
    cap_drop: [ALL]
    deploy:
      resources:
        limits: { cpus: "2", memory: 1G }
```

- `depends_on` with a `condition` waits for health, not just for the container to start.
- `restart: unless-stopped` so the service comes back after a reboot.
- Pin the image tag. `latest` makes every host different.

## Troubleshooting

| Symptom | Likely cause | Check |
|---------|--------------|-------|
| Service restarts in a loop | Crash on startup | `docker logs`, check the exit code |
| Works locally, fails in the image | Missing system library or wrong base | Compare the base image and the installed packages |
| Cannot write files | Non-root user, no writable mount | `id`, check the volume ownership |
| Out of memory | Unbounded memory, or the limit is too low | `docker stats`, check the limit |
| Signals ignored | Shell-form entrypoint, or not PID 1 | Use exec form, add `--init` |
| Image is huge | Build tools and caches in the final layer | `docker history`, use multi-stage |
