# Serving and Inference

## Architecture

**The model file is an artifact, not a process.** Train it, version it, register it, load it at service startup.

```text
training job -> artifact store -> model registry -> serving service
                    |                                    |
              experiment tracker              loads once at boot
```

- Never train and serve in the same process. A training job that leaks memory takes the service down.
- The serving service loads the model once at startup and keeps it in memory. Never reload per request.
- The artifact carries: the model file, the preprocessing pipeline, the feature schema, the label definition, the training data version, the evaluation metrics, and the environment it was built for.
- A model without its feature definition cannot be reproduced. Store the pipeline with the model.

## Deployment options

| Option | Use when | Cost |
|--------|----------|------|
| In-process library | Small model, low traffic, same language as the service | Lowest |
| Dedicated inference service | Model is large, traffic is bursty, multiple consumers | Medium |
| Shared model server (Triton, TorchServe, KServe) | Many models, GPU, batching, autoscaling | Medium |
| Serverless inference | Spiky traffic, cold starts acceptable | Variable |
| Batch scoring | Low latency sensitivity, high volume | Lowest per prediction |

**In-process** is the right default. Reach for a separate service only when the model is big, the traffic pattern is bursty, or several consumers need it.

## Latency

Decompose the end-to-end budget and measure each part:

```text
total = feature fetch + model inference + post-processing + network
```

- The feature fetch is often slower than the model. Measure it separately.
- Set a timeout on the whole request and on each dependency.
- Define the fallback behaviour for a timeout: a rule-based answer, a cached answer, or a graceful error. The request must still succeed.
- Measure p95 and p99, not the mean.

### Batching

GPU inference is dominated by per-request overhead. Batch concurrent requests into one forward pass.

- A micro-batching layer with a small wait (1-10 ms) collects concurrent requests.
- Larger batches mean better GPU utilisation but more latency for the first request in the batch.
- Tune the batch size and the wait against the latency target.
- On CPU inference, batching helps less but vectorisation still helps.

### Quantization

- INT8 quantization typically halves the memory and doubles the throughput.
- Validate the accuracy loss on the test set before shipping. The loss is usually small, but it must be measured.
- Quantize the model at build time and store the quantized artifact. Do not quantize on every load.

### Optimisation

- Use ONNX Runtime or a compiled runtime instead of the raw framework.
- `torch.compile` or an equivalent for the graph-level compilation.
- Graph optimisation and operator fusion at load time.
- Half precision (FP16) on GPUs with tensor cores.

## Serving patterns

**Synchronous** - the request waits for the prediction. Simple, and the latency is on the critical path.

**Asynchronous** - the request returns a job ID and the client polls or receives a webhook. Use when the prediction takes longer than the request budget.

**Batch / nightly** - score everything offline and serve from a lookup table. Best when the prediction does not depend on real-time features. Often the cheapest option by far.

**Streaming** - score each event as it arrives, and act on the result.

## A/B testing

- **Offline metrics do not predict online lift.** Test on real traffic.
- Randomise by **user**, not by session. Otherwise the same user sees two variants and the results are contaminated.
- Run for a full business cycle. A weekday is not representative of a weekend.
- Compute the sample size and the minimum detectable effect in advance. A test that cannot detect a realistic effect is a waste of traffic.
- Guard against novelty and primacy effects.
- Have a rollback plan before starting.
- Watch for a metric that improves while a guardrail metric degrades.

```python
# assignment must be sticky per user
bucket = hashlib.sha256(f"{user_id}:{experiment_id}".encode()).hexdigest()[:8]
variant = "control" if int(bucket, 16) % 100 < 50 else "treatment"
```

## Monitoring

**Service health** (is the model serving?)

- Request rate, error rate, latency percentiles per model version.
- Inference failures and the fallback rate.
- GPU utilisation and memory.
- Model load failures.

**Data drift** (is the input distribution changing?)

- Feature distribution vs the training baseline: population stability index, or a simple quantile comparison.
- Null rate and range per feature. A sudden zero is an upstream outage.
- The distribution of the predictions. A collapse in the predicted class distribution means something broke.

**Concept drift** (is the model still accurate?)

- Requires labels, which usually arrive late. Track performance on a delayed label.
- Compare the current metric against the training-time metric on the same segment.

**Business metrics** (does the model still help?)

- The metric the model was built for, downstream of the prediction.

**Drift detection**: alert on a significant shift, but do not auto-retrain. A drift alert should trigger an investigation, not a blind retrain.

## Retraining

- **Triggers**: a schedule, a drift threshold, a data volume threshold. A time-based trigger is the simplest and most predictable.
- **Champion/challenger**: the current model keeps serving. The candidate is evaluated offline, then in shadow (live traffic, no effect), then in a canary, then promoted.
- **Every candidate must pass the same evaluation gate** as the original. A retrained model is not automatically better.
- **Version the model, the features, and the code together.** A model without its feature version is unreproducible.
- **Never retrain on the live serving path.** Retraining is a separate job.

## Rollback

- The previous model version must remain deployable and loadable.
- Rolling back must not require a feature change. If a feature changed, the old model may not accept the new features. Keep the feature schema backward compatible, or version the feature contract with the model.
- A model that can be loaded and evaluated in a CI job, against a golden dataset, before promotion.

## Cost

- **Cost per inference** is the number that scales with traffic. Track it.
- GPU utilisation. An idle GPU is pure cost.
- Batch scoring offline is usually an order of magnitude cheaper than serving.
- Right-size the instance. Do not run a 10-request-per-second workload on an A100.
- Cache predictions for repeated inputs when the features are stable.

## Failure modes

| Failure | Detection | Response |
|---------|-----------|----------|
| The model fails to load | Startup health check | Refuse to start; do not serve without a model |
| Inference times out | Latency alert | Fall back to the rule-based path |
| The feature store is down | Dependency error rate | Serve from a cached feature snapshot, or fail open to a rule |
| The input distribution shifted | Drift alert | Investigate; consider a fallback |
| The model degrades in production | Delayed-label performance | Roll back to the champion |
| A feature pipeline broke | Null-rate and range alerts | The null-rate alert should catch it before the model does |

**A serving service with no fallback is a single point of failure.** The fallback path must be tested, not just written.

## Anti-patterns

- Loading the model per request.
- Retraining in the serving process.
- No fallback, so a slow model is an outage.
- A/B testing by session rather than by user.
- Deploying without a champion to roll back to.
- Reporting the offline metric as if it were the online result.
- Unbounded feature fetches, so the model latency is dominated by I/O.
- No cost tracking, so the GPU bill arrives as a surprise.
