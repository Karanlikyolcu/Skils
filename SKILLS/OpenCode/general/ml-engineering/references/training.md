# Training

## Datasets

**The dataset is the product.** Model quality is bounded by data quality, and a well-tuned model on bad data is a well-tuned model on bad data.

### Label quality

- **Measure it.** Sample labels and have a second annotator review them. Inter-annotator agreement (Cohen's kappa for two annotators, Krippendorff's alpha for more) sets the ceiling on model quality. Humans at 70% agreement means the model will not reliably exceed that.
- **Write an annotation guideline.** Definitions, edge cases, examples. Without it, the labels drift.
- **Spot-check after every labelling round.** A new batch may have a systematic error.
- **Adjudicate disagreements** rather than averaging them. A human decides, and the guideline is updated.

### Leakage

The single most common cause of a model that is excellent offline and useless in production.

- **Target leakage**: a feature that is a consequence of the label. `account_closed_date` in a churn model. `days_until_invoice_paid` in a payment-default model.
- **Temporal leakage**: training on data from after the prediction moment. The classic case is a random split over time-ordered data.
- **Group leakage**: the same user, patient, device, or session appears in both train and test. The model memorises the group.
- **Duplicate leakage**: the same record in both splits.

Detection:
- Train a model on a shuffled split with a suspicious feature and check the AUC. Near 1.0 means leakage.
- Check feature importance. A feature that dominates is worth investigating.
- Feature importance computed on the full data, then compared with importance computed only on the training set. A large gap indicates leakage.

### Splits

- **Split by time** for anything temporal. Train on the past, validate on the middle, test on the most recent.
- **Group-aware split** when the same entity appears repeatedly: split by entity, not by row.
- **Deduplicate before splitting.**
- **Stratify** on the target for classification, so a rare class is represented proportionally in every split.
- **Freeze the split** in code and version it with the dataset. Changing the split invalidates every historical metric comparison.
- **Touch the test set once.** Every time you evaluate against it and then change something, it becomes a validation set.

## Reproducibility

Every run must be re-creatable.

```yaml
run:
  code_version: a3f9c21
  dataset_version: orders_2026-01-14_v3
  split_version: split_2026-01-01
  environment: docker://registry/ml/train@sha256:9f2e...
  seed: 42
  hyperparameters:
    learning_rate: 0.001
    n_estimators: 800
    max_depth: 6
    subsample: 0.8
```

- Track the code version, the dataset version, the environment, the seed, the hyperparameters, and the resulting metrics.
- Pin the environment by digest, not by tag.
- Use an experiment tracker (MLflow, W&B, or a metadata table). A CSV in the repo does not scale but is better than nothing.
- The seed is necessary but not sufficient. GPU kernels and some libraries are not bit-reproducible across hardware or versions, so the environment matters more than the seed.
- Log the resolved config, not just the config file. Defaults and environment overrides change the actual run.

## Data splits and leakage in code

```python
# Temporal split - correct
train = df[df.date < "2026-01-01"]
valid = df[(df.date >= "2026-01-01") & (df.date < "2026-02-01")]
test  = df[df.date >= "2026-02-01"]

# Random split - wrong for temporal data
train, test = train_test_split(df, test_size=0.2, random_state=42, stratify=df.label)
```

For a grouped split:

```python
from sklearn.model_selection import GroupShuffleSplit
splitter = GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=42)
train_idx, test_idx = next(splitter.split(X, y, groups=df.customer_id))
```

## Preprocessing

- Fit the preprocessor **on the training set only**, then apply it to validation and test. Fitting on the full dataset leaks the test statistics into the model.
- Use a `Pipeline` so the fit is encapsulated and cannot leak by accident.
- **Scaling**: standardise for linear models, logistic regression, SVM, k-NN, and neural networks. Tree models generally do not need it.
- **Categorical encoding**: target encoding needs a fold-aware implementation (out-of-fold), otherwise it leaks. One-hot for low cardinality, embeddings for high cardinality in neural models.
- **Missing values**: a missing value is often informative. Add an explicit "is_missing" indicator rather than only imputing.
- **Outliers**: decide by domain, not by a z-score cutoff. A 5000 ms latency might be the most important row in the dataset.

```python
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression

pipe = Pipeline([
    ("impute", SimpleImputer(strategy="median", add_indicator=True)),
    ("scale",  StandardScaler()),
    ("model",  LogisticRegression(max_iter=1000)),
])
pipe.fit(X_train, y_train)     # fit happens on train only
```

## Class imbalance

- **Stratify** the split so the rare class is represented proportionally.
- **Class weights** in the loss function. The simplest and most reliable fix. It directly encodes the error cost.
- **Resampling** (oversampling the minority, undersampling the majority) is a last resort. It changes the prior and distorts the calibration, and it can leak by duplicating rows across splits.
- **Never report accuracy on an imbalanced problem.** A 99% accurate model that never predicts the rare class is worthless.

```python
model = LogisticRegression(class_weight={0: 1.0, 1: 50.0})
```

## Hyperparameter search

- **Random search** beats grid search for the same budget. It explores the space better and does not waste budget on irrelevant combinations.
- **Bayesian optimisation** (Optuna, Hyperopt) is better still, and handles conditional parameters.
- Search over a sensible range, informed by the literature for the model, not over arbitrary powers of ten.
- Use early stopping with a validation set as one of the search dimensions.
- Always search on the validation set. The test set stays untouched.

```python
from sklearn.model_selection import RandomizedSearchCV
from scipy.stats import loguniform

search = RandomizedSearchCV(
    pipe,
    param_distributions={
        "model__learning_rate": loguniform(1e-4, 1e-1),
        "model__n_estimators": [200, 400, 800, 1200],
        "model__max_depth": [None, 4, 6, 10],
    },
    n_iter=50, cv=5, scoring="average_precision", n_jobs=-1,
)
search.fit(X_train, y_train)
```

## Evaluation

### Choosing a metric

| Problem | Use |
|---------|-----|
| Imbalanced binary classification | PR-AUC (average precision) |
| Balanced binary classification | ROC-AUC |
| Probability output that must be calibrated | Log loss, Brier score |
| Cost-sensitive decision | The business cost metric |
| Multi-class | Macro-averaged F1 (not micro, which hides the rare classes) |
| Regression | MAE (interpretable), RMSE (penalises large errors), MAPE (careful with zeros) |
| Ranking | NDCG or MAP@K |

**Always compare against a baseline.** A trivial baseline (the majority class, a heuristic rule, the current production rule) is the minimum bar.

```python
from sklearn.metrics import average_precision_score, roc_auc_score

print("baseline (always positive):", average_precision_score(y_test, np.ones(len(y_test))))
print("model:                    ", average_precision_score(y_test, model.predict_proba(X_test)[:, 1]))
```

### Segment the results

Overall metrics hide a model that is excellent for one segment and useless for another.

- Report by the segments that matter: country, customer tier, device, language, new vs returning, time of day.
- A model with a good overall AUC and a terrible AUC for your largest paying segment is not a good model.
- Slice size matters. A segment with 50 samples has a metric with a huge confidence interval.

### Calibration

If the model outputs a probability, check that it means what it says.

```python
from sklearn.calibration import calibration_curve
frac_pos, mean_pred = calibration_curve(y_test, y_prob, n_bins=10)
# A well-calibrated model: frac_pos tracks mean_pred closely
```

- A ranking model (good AUC) is often badly calibrated (probability 0.9 means 40%).
- Calibrate with isotonic regression or Platt scaling on a held-out set.
- Calibration is per-segment. It can be well calibrated overall and badly calibrated for a key segment.

### Error analysis

Look at the actual failures. This finds more improvement than any amount of hyperparameter tuning.

- Sample 100-200 errors and categorise them: missing signal, wrong label, ambiguous case, out-of-distribution input, a feature that misleads.
- Fix the biggest category. The biggest category is usually not the most embarrassing one.
- Some errors are irreducible. Label noise sets a floor.

### Statistical significance

- A 0.5% AUC improvement on a small test set is noise. Use a bootstrap confidence interval or a paired test.
- Compare models on the same test set with a paired bootstrap, not two independent intervals.

### What to report

- The metric, on a named split, with the baseline comparison.
- The segment breakdown.
- The confidence interval.
- The known limitations and the population it was validated on.
- The training data date range. A model is only valid for the period it was trained on.

## Anti-patterns

- Accuracy on an imbalanced problem.
- A random split over time-ordered data.
- Fitting the preprocessor on the full dataset.
- Tuning hyperparameters against the test set.
- Reporting only the aggregate metric.
- No baseline comparison, so "accuracy 0.94" means nothing.
- Assuming the offline metric predicts the online lift.
- A model deployed without a fallback for when it is unavailable.
- Retraining on a schedule with no evaluation gate.
