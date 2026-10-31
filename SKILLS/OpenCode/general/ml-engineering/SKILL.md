---
name: ML Engineering
description: Use for machine learning engineering - dataset design and labelling, feature engineering, training pipelines and reproducibility, evaluation and offline metrics, serving and online inference, feature stores, drift and retraining, LLM applications with retrieval augmented generation, guardrails and evaluation, experiment tracking, and MLOps infrastructure.
metadata:
  opencode/autoinvoke: true
license: MIT
---

# ML Engineering

A model is one component in a system. The system decides whether it works, and the system is where the failures live.

## 1. Define the objective before the model

Write this down before touching data:

- **The decision** the prediction supports. A prediction that informs no action is not worth serving.
- **The metric** that reflects that decision, and its business mapping.
- **The baseline** it must beat. A trivial baseline (a constant, a heuristic, the current rule) is the minimum bar. Most first models fail to beat it.
- **The error cost**: what does a false positive cost, and what does a false negative cost? They are rarely equal. A medical or fraud model with asymmetric costs should use a weighted metric, not accuracy.
- **The decision threshold** and who owns it. Threshold tuning is a business decision, not a modelling detail.

If the objective cannot be written in one paragraph, the project is not ready.

## 2. Data

**The dataset is the product.** Model quality is bounded by data quality.

- **Label quality dominates everything.** Check label accuracy by sampling and by inter-annotator agreement (Cohen's kappa, Krippendorff's alpha). If humans agree only 70% of the time, no model will exceed that reliably.
- **Label leakage** is the classic silent failure: a feature that is a consequence of the target, or data that contains the answer. Train-serving skew and temporal leakage both show up as unrealistically good offline metrics.
- **Split by time**, not randomly, for anything temporal. A random split lets the model see the future.
- **Deduplicate** before splitting. The same record on both sides inflates the metric.
- **Watch for group leakage**: the same user, patient, or device in both train and test.
- Inspect the label distribution and the feature distribution per split. A shift between train and test is a bug, not a surprise.

**Dataset versioning**

- Every training run points at an immutable dataset version: the source data hash, the transformation code version, and the split definition.
- Keep the split definition in code, and freeze it. Changing the split invalidates every historical comparison.
- Store the label definitions and the annotation guidelines with the dataset version.

## 3. Features

- **A feature store or a shared feature pipeline** so training and serving compute the same value. Otherwise you get training-serving skew, which is the most common cause of "the model was great offline and terrible in production".
- **Point-in-time correctness** when joining features to labels. Join on the event timestamp, never on the current value of the feature. A feature that is fetched "as of now" during training is leakage.
- **Transform once, reuse everywhere.** The same function computes the feature in training and in serving.
- **Feature freshness** is a first-class concern. A model on stale features degrades quietly.
- **Feature monitoring**: distribution, null rate, and range for every feature, checked continuously. A feature that suddenly becomes constant is usually an upstream outage.
- Keep the feature set small. Each feature is a maintenance burden and a leak risk.

## 4. Training and reproducibility

- **Track everything**: the code version, the dataset version, the hyperparameters, the environment, the seed, and the resulting metrics. Use an experiment tracker (MLflow, Weights & Biases, or a simple metadata table).
- **Fix the seed** and log it. Determinism is not guaranteed across hardware or library versions, so also log the environment.
- **The environment is pinned**: the base image by digest, the dependency versions, the CUDA version, the driver version.
- **Seed from a validated split**: train, validation, test. Touch the test set once, at the end. Repeatedly tuning against the test set makes it a validation set.
- **Scaling**: standardise features for linear models and distance-based methods. Tree models generally do not need it.
- **Class imbalance**: use stratified splits, class weights, or resampling. Choose based on the error cost, and report the metric that reflects it.
- **Hyperparameter search**: a random or Bayesian search over a sensible range beats a manual grid for the same budget.
- **Early stopping** on the validation set.

## 5. Evaluation

**Offline metrics**

- Choose the metric that matches the decision: PR-AUC for rare positive classes, ROC-AUC for balanced ranking, log loss for calibrated probability, MAE/MAPE for regression, and the business cost metric for the real objective.
- **Always compare against the baseline.** A model with 0.92 AUC that beats a 0.90 baseline is worth less than one that beats a 0.55 baseline by a wide margin.
- **Segment the results.** Overall metrics hide a model that is excellent for one segment and useless for another. Report by key cohorts.
- **Calibration**: if you output a probability, check that a 0.8 bucket really is 80% correct (reliability diagram, Brier score).
- **Error analysis**: look at the actual failures. Categorize them. Fix the biggest category, not the most embarrassing one.

**Caveats that must be stated**

- The offline metric is an estimate. The only real test is production.
- Proxy metrics are proxies. State the assumption connecting them to the true objective.
- The test set is a sample, not the population. Report a confidence interval where it matters.

## 6. Serving and inference

- **The model file is an artifact**, versioned, stored in a model registry, and loaded by the service at startup. Never train and serve in the same process.
- **Prefer a separate inference service** when the model is large or the traffic pattern is bursty. A shared model server (Triton, TorchServe, KServe) handles the scaling.
- **Batch the requests** for GPU inference. Per-request inference on a GPU is dominated by overhead.
- **Quantize** (INT8) where the accuracy loss is acceptable. It typically halves the memory and doubles the throughput.
- **Cache** the model in memory, load it once, and never reload it per request.
- **Set a timeout** on inference and define the fallback behaviour. If the model times out, the request must still succeed with a rule-based answer.
- **Batch predictions offline** for low-latency-critical volume: score nightly instead of per request.

**Latency budget**

Decompose the end-to-end budget: feature fetch, model inference, and post-processing. Measure each. The feature fetch is often slower than the model.

**A/B testing**

- Offline metrics do not predict online lift. Test on real traffic.
- Randomize by user, not by session, or the same user sees both variants.
- Run for a full business cycle. A weekday is not representative.
- Pre-compute the sample size and the minimum detectable effect. A test that cannot detect a realistic effect is a waste.
- Guard against novelty and primacy effects.

## 7. Monitoring and drift

**Data drift** - the input distribution changed.
**Concept drift** - the relationship between inputs and the target changed. Far more dangerous, and much harder to detect.

Monitoring signals:

- **Feature distributions** against the training baseline (population stability index, or a simple drift metric). Alert on significant shifts.
- **Prediction distribution**: if the predicted class distribution collapses, something is wrong upstream.
- **Null rate and range** per feature. A sudden zero is an outage.
- **Model performance** on a delayed label, when labels arrive late. This is the only true signal of concept drift.
- **Business metrics** downstream. The model is only good if the business metric moves.

**Retraining**

- Trigger on a schedule, on drift, or on a data volume threshold. A time-based trigger is the simplest and most predictable.
- The retrained model must pass the same evaluation gate as the original. A retrained model is not automatically better.
- Champion/challenger: keep the current model serving, evaluate the candidate offline and in a shadow or canary, then promote.
- Version the model, the features, and the code together. A model without its feature definition is unreproducible.

## 8. LLM applications

**RAG pipeline**

- Chunk documents by semantic boundaries, not by a fixed token count. Keep a chunk with its source metadata: URI, section, title, and a retrieval timestamp.
- **Embed** with a model chosen for the domain. Chunk size and overlap must be tuned against real retrieval recall, not guessed.
- **Hybrid retrieval**: combine dense vectors with BM25 keyword search. It reliably beats either alone, because exact terms (identifiers, error codes, names) matter.
- **Rerank** the top candidates with a cross-encoder. It is the single highest-leverage accuracy improvement.
- **Filter by metadata** before or after retrieval: tenant, permission, product, document type. Never let retrieval surface a document the user may not read.
- **Cite the source** in the answer, and verify the cited chunk actually supports the claim.

**Evaluation**

- Build a golden dataset of real questions with expected answers and expected sources. Without it, there is no way to tell if a change helped.
- Evaluate the retrieval stage separately from the generation stage. A good answer built on a bad retrieval is a lucky answer.
- Metrics: recall@k and MRR for retrieval; faithfulness and answer relevance for generation; and an LLM-as-judge with a rubric, calibrated against human labels on a sample.
- Test for the failure modes: hallucination, out-of-date knowledge, prompt injection in retrieved content, and refusal when the answer is not in the corpus.

**Guardrails**

- Treat retrieved content as untrusted input. Sanitize it. A document containing instructions is an injection vector.
- Delimit retrieved content explicitly and instruct the model to treat it as data, not instructions.
- Constrain the output: structured output with a schema, and validate it before use.
- Add a citation requirement, and reject answers whose citations do not support the claim.
- Rate limit and cap the token budget per request.
- Keep the model output away from any action that touches money, permissions, or data deletion without a deterministic check in between.

## 9. MLOps infrastructure

- **Training pipeline**: versioned code, pinned environment, immutable dataset, tracked artifacts.
- **Registry**: model versions, metrics, lineage (which dataset, which code, which features).
- **Deployment**: the same artifact is promoted through environments. No retraining on the serving path.
- **Serving**: autoscaling on GPU or request rate, with a queue if the GPU is saturated.
- **Lineage**: from a prediction back to the exact model version, the feature values, and the source data. Without it, a bad prediction cannot be explained.
- **Cost**: GPU utilization, idle capacity, and the cost per training run. Train less often than you think you need to.

## 10. Common mistakes

- Measuring accuracy on an imbalanced problem and calling it done.
- Randomly splitting temporal data, so the model trained on the future.
- Leakage through a feature computed after the label.
- Training and serving compute features differently.
- Tuning hyperparameters against the test set.
- Skipping the baseline comparison.
- Reporting only the aggregate metric, hiding a broken segment.
- Deploying without a fallback for when the model is unavailable.
- Retraining on a schedule and promoting without an evaluation gate.
- RAG with no golden dataset, so every change is a guess.

## Supporting files

- `references/training.md` - datasets, splits, leakage, reproducibility, tuning, evaluation metrics.
- `references/serving.md` - inference architecture, latency, quantization, A/B tests, monitoring, drift.
- `references/feature-store.md` - feature definitions, point-in-time joins, offline/online parity, monitoring.
- `references/llm-rag.md` - chunking, embedding, hybrid retrieval, reranking, evaluation, guardrails.
