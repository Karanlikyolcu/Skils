# Kubernetes

## Workloads

| Resource | Use for |
|----------|---------|
| `Deployment` | Stateless services, rolling updates |
| `StatefulSet` | Stateful workloads needing stable identity and ordered rollout |
| `DaemonSet` | One pod per node (agents, log collectors) |
| `CronJob` | Scheduled work |
| `Job` | One-off work |
| `ReplicaSet` | Rarely used directly; a Deployment manages one |

## A minimal Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels: { app: api }
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate: { maxSurge: 1, maxUnavailable: 0 }
  selector:
    matchLabels: { app: api }
  template:
    metadata:
      labels: { app: api }
    spec:
      serviceAccountName: api
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        fsGroup: 10001
        seccompProfile: { type: RuntimeDefault }
      containers:
        - name: api
          image: registry.example.com/api:1.4.2   # pinned tag or digest
          ports: [{ containerPort: 8080 }]
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef: { name: api-secrets, key: database-url }
          resources:
            requests: { cpu: 100m, memory: 256Mi }
            limits:   { cpu: "1",  memory: 512Mi }
          readinessProbe:
            httpGet: { path: /readyz, port: 8080 }
            initialDelaySeconds: 5
            periodSeconds: 5
            failureThreshold: 3
          livenessProbe:
            httpGet: { path: /healthz, port: 8080 }
            periodSeconds: 10
            failureThreshold: 3
          lifecycle:
            preStop:
              exec: { command: ["sleep", "5"] }
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities: { drop: ["ALL"] }
          volumeMounts:
            - { name: tmp, mountPath: /tmp }
      volumes:
        - name: tmp
          emptyDir: {}
```

## Probes

Three different probes, three different jobs:

| Probe | Question | Consequence of failure |
|-------|----------|----------------------|
| `startupProbe` | Has the app finished starting? | Kills the liveness check until it passes |
| `readinessProbe` | Can this pod serve traffic now? | Removed from the Service endpoints |
| `livenessProbe` | Is this process wedged? | The container is restarted |

- **Never make the liveness probe depend on an external dependency.** If the database blips and the liveness probe calls it, every pod restarts at once, and the outage becomes a crash loop.
- The readiness probe may check dependencies, but keep it cheap. A slow readiness probe removes a healthy pod from the load balancer.
- `startupProbe` with a generous `failureThreshold` handles slow starts without weakening the liveness probe.
- `preStop: sleep 5` gives the endpoint propagation time so in-flight requests are not cut.

## Resources

- Always set requests and limits. No requests means the scheduler overcommits and the node runs out of memory.
- Requests drive scheduling. Limits drive the cgroup.
- Memory limits are hard: exceeding them gets the pod OOM-killed. CPU limits throttle rather than kill.
- Start with requests based on measured usage under load, not guesses.
- A limit that is too tight causes throttling and latency spikes. A limit that is too loose lets one pod starve the node.

## Configuration and secrets

- `ConfigMap` for non-sensitive configuration. `Secret` for sensitive values.
- A `Secret` is base64-encoded, not encrypted. Enable encryption at rest for etcd, and prefer an external secret manager (Vault, External Secrets Operator, cloud secret manager).
- Mount secrets as files rather than environment variables when the application supports it. Environment variables leak into `/proc`, crash dumps, and child processes.
- Never put a secret in a ConfigMap, an image, or a git repository.
- Rotate secrets and restart the pods. If a secret is read at startup, a rotation with no restart changes nothing.

## Networking

- `Service`: stable DNS and a virtual IP. `ClusterIP` for internal, `NodePort` for direct node access, `LoadBalancer` for cloud.
- `Ingress`: HTTP routing. Needs an ingress controller. TLS terminates there.
- `NetworkPolicy`: restrict which pods may talk to which. Default deny, then allow explicitly.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: api-allow-dns }
spec:
  podSelector: { matchLabels: { app: api } }
  policyTypes: [Ingress, Egress]
  ingress:
    - from: [{ namespaceSelector: { matchLabels: { name: ingress } } }]
      ports: [{ protocol: TCP, port: 8080 }]
  egress:
    - to: [{ namespaceSelector: { matchLabels: { name: kube-system } } }]
      ports: [{ protocol: UDP, port: 53 }]
```

- A namespace-level default deny plus per-workload allows is the practical pattern.
- Egress restrictions are the ones people skip, and they are the ones that limit exfiltration.

## Deploying safely

```sh
kubectl apply --dry-run=server -f manifest.yaml   # validate
kubectl apply -f manifest.yaml
kubectl rollout status deployment/api --timeout=5m
kubectl rollout undo deployment/api                # rollback
```

- `kubectl apply`, never `kubectl edit`. An edit is invisible to the next apply and disappears on the next deploy.
- The manifest in the repository is the source of truth. If a change matters, commit it.
- `maxUnavailable: 0` with `maxSurge: 1` keeps full capacity during a rollout, at the cost of an extra pod.
- The new version must be backward compatible with the old during the rollout. Database changes use expand/contract.
- Use a `PodDisruptionBudget` so a node drain does not take the whole service down.

## Configuration for different environments

- One manifest template, different values per environment, rendered by Kustomize or Helm.
- Never branch the manifest on the environment with `if` statements in a template. That produces configuration nobody has seen.
- Environment-specific values are values, not conditionals: images, replicas, resources, and secrets differ; the structure does not.

## Common problems

| Symptom | Likely cause | Check |
|---------|--------------|-------|
| Pod stuck in `Pending` | No node fits the requests, or no PVC bound | `kubectl describe pod` |
| Pod in `CrashLoopBackOff` | The process exits | `kubectl logs --previous` |
| Pod running but not receiving traffic | Readiness probe failing | `kubectl describe pod`, check the endpoints |
| OOMKilled | Exceeded the memory limit | `kubectl describe pod`, check `lastState` |
| Pending image pull | Bad tag, or no image pull secret | `kubectl describe pod` |
| Service returns 503 | No ready endpoints | `kubectl get endpoints` |
| Slow after a rollout | New pods not ready yet | Check the readiness probe and startup time |
| Volume not mounting | StorageClass missing, or the PVC is pending | `kubectl get pvc` |

## Useful commands

```sh
kubectl get pods -o wide
kubectl describe pod <pod>            # events, probe failures, scheduling
kubectl logs <pod> --previous          # the logs from before the last crash
kubectl logs -f <pod> --since=10m
kubectl get events --sort-by=.lastTimestamp | tail -30
kubectl top pods --sort-by=memory
kubectl exec -it <pod> -- sh
kubectl port-forward svc/api 8080:80
kubectl diff -f manifest.yaml         # what would change
```
