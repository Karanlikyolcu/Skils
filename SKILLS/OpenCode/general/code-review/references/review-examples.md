# Review Examples

Real comments, with the reasoning made explicit.

---

## Example 1: N+1 query

```diff
 def get_orders_for_user(user_id: str) -> list[Order]:
     orders = db.query(Order).filter(Order.user_id == user_id).all()
-    for order in orders:
-        order.customer = db.query(Customer).get(order.customer_id)
     return orders
```

> **[blocking]** This is an N+1: one query per order. With the average customer having 40 orders, a page of 20 orders becomes 21 queries, and it grows linearly with the page size.
> `src/api/orders.py:42`
> Use the eager load: `db.query(Order).options(joinedload(Order.customer)).filter(...).all()`. The serializer already accesses `order.customer`, so this changes nothing else.

**Why this is well formed:** names the pattern, quantifies the impact, points at the exact line, and gives a one-line fix that matches the surrounding code.

---

## Example 2: Missing authorization check

```diff
 @router.get("/orders/{order_id}")
 def get_order(order_id: str, user=Depends(current_user)):
-    return db.query(Order).get(order_id)
+    return db.query(Order).filter(Order.id == order_id).first()
```

> **[blocking]** This returns any order by ID, regardless of who owns it. Any authenticated user can read any other user's order, including their address and payment details. This is an IDOR.
> `src/api/orders.py:31`
> Filter by the owner as well: `db.query(Order).filter(Order.id == order_id, Order.user_id == user.id).first()`. There is already a `user_can_access_order` helper in `src/orders/access.py` - it also covers the admin case, so use that.

**Why this is well formed:** states the vulnerability class, the concrete impact (which data leaks), and points to an existing helper rather than inventing a new pattern.

---

## Example 3: A question, not a defect

```diff
 def process_webhook(payload: dict) -> None:
+    if payload["type"] == "order.created":
+        create_order(payload["data"])
```

> **[question]** What happens if the same webhook is delivered twice? I cannot see an idempotency key or a uniqueness check on `create_order`. If the provider retries, this would create a duplicate order.
> `src/webhooks/orders.py:14`
> Is there a dedup on `payload["id"]` upstream, or should this check it?

**Why this is well formed:** it separates the uncertainty from the defect, states the concrete failure scenario, and asks a specific answerable question rather than asserting a bug.

---

## Example 4: Silent behaviour change

```diff
-PAGINATION_LIMIT = 20
+PAGINATION_LIMIT = 100
```

> **[should-fix]** This raises the page size from 20 to 100, which is a 5x increase in the number of rows and the memory per request. For a customer with many orders, the response could be several megabytes.
> `src/api/orders.py:9`
> If the goal was to reduce the number of round trips, a cursor would give that without the payload increase. If the old limit was a real problem, worth a separate ticket with the reason, since it changes the API contract's practical behaviour.

**Why this is well formed:** quantifies the impact, asks about the intent before assuming the change is wrong, and offers an alternative that solves the stated problem.

---

## Example 5: Catching an exception too broadly

```diff
 try:
     result = api.fetch_order(order_id)
-    return result
 except Exception:
-    return None
```

> **[should-fix]** This catches everything, including `KeyboardInterrupt`, `MemoryError`, and programming errors like `AttributeError`, and turns them into a `None` return. The caller cannot tell "the order does not exist" from "the API is down", so a provider outage looks like an empty result.
> `src/orders/client.py:22`
> Catch the specific exceptions the API client raises (`OrderNotFound`, `ApiTimeout`), and let anything else propagate.

**Why this is well formed:** explains the mechanism (exception hierarchy, control flow), the specific consequences, and the fix, without claiming the code is broken today.

---

## Example 6: A missing test

```diff
+def apply_discount(order: Order, code: str) -> Decimal:
+    discount = discount_repo.find(code)
+    if discount is None:
+        raise DiscountNotFound(code)
+    if discount.expires_at < order.ordered_at:
+        raise DiscountExpired(code)
+    return order.total * (1 - discount.percentage)
```

> **[should-fix]** No test for this. The expired-discount branch looks reachable - a discount that expired between adding it to the cart and checkout is a normal case, not an edge case.
> `src/orders/discounts.py:8`
> At minimum: a valid discount applies, an unknown code raises `DiscountNotFound`, an expired discount raises `DiscountExpired`, and a discount that expired after the order was placed still applies.

**Why this is well formed:** identifies the specific untested branch, argues why it matters in practice, and lists the cases rather than vaguely asking for "more tests".

---

## Example 7: Praise, specific

```diff
+    # Retry with exponential backoff. The provider returns 429 with a
+    # Retry-After header, so respect it when present.
+    for attempt in range(max_retries):
+        try:
+            return session.get(url, timeout=timeout)
+        except TransientError:
+            if attempt == max_retries - 1:
+                raise
+            sleep(backoff(attempt))
```

> The retry logic is right - it respects `Retry-After`, it bounds the attempts, and it re-raises rather than swallowing the last error. The comment explains why the `Retry-After` branch exists, which is the part people usually get wrong later.
> `src/http/client.py:22`

**Why this is well formed:** names the three specific properties that are correct and that a future maintainer might otherwise break. It is not praise for the sake of it.

---

## Example 8: Too big to review

```diff
 (4000 lines changed across 47 files)
```

> **[blocking]** This is 4000 lines across 47 files, which is not reviewable in one pass, and the diff mixes a refactor with at least three separate behaviour changes.
>
> Please split it into:
> 1. The pure refactor (no behaviour change) - reviewable on its own
> 2. The discount feature
> 3. The API response shape change (this one needs a version bump and a deprecation path)
> 4. The test migration
>
> The refactor should land first on its own, so the feature diff shows only the feature.

**Why this is well formed:** gives a specific, actionable decomposition rather than a complaint about size, and explains the benefit (the feature diff shows only the feature).

---

## Example 9: An optional suggestion, clearly optional

```diff
-    total = sum(items)
+    total = sum(item.price * item.quantity for item in items)
```

> **[optional]** `sum()` over a generator is slightly clearer than the list comprehension here. Not important either way.
> `src/cart.py:22`

**Why this is well formed:** marked optional, brief, and it does not pretend to be a defect. A reader who disagrees can ignore it without any guilt.

---

## Anti-patterns in comments

| Do not write | Write instead |
|--------------|----------------|
| "This is bad code" | What is wrong, why it matters, and the fix |
| "You should have used a transaction" | "These two writes are not atomic. If the second fails, the first is already committed. Wrap both in a transaction." |
| "Why didn't you use the repository?" | "This bypasses the repository, so the cache and the retry logic are skipped. It also hardcodes the table name." |
| "nit: rename this" | "[optional] `userList` -> `users`, for consistency with the rest of the codebase" |
| "This will break in production" | "Under concurrent writes this read-modify-write can lose an update. Two requests updating the counter can result in one increment." |
| "I would have written it differently" | A problem with the current approach, and the alternative, if there is one |
