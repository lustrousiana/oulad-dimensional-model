# OULAD Pipeline Validation

How we know the pipeline works.

This document covers the data quality framework: where results live, what each
column means, why the design choices were made, and what the current numbers
say. For *why the pipeline is built the way it is*, see `decisions.md`. For
*what each field means*, see `data_dictionary.md`.

<br>

## 1. Current state of all three layers

| Layer | Checks | PASS | WARN | **FAIL** | Pass rate |
|---|---|---|---|---|---|
| Raw | 73 | 60 | 5 | **0** | 92.3% |
| Clean | 78 | 62 | 8 | **0** | 88.6% |
| Mart | 60 | 52 | 1 | **0** | 98.1% |

**Zero failures at every layer.** Every exit gate is clear.

Two things resolved since the previous version of this document:

- **Clean went from 9 failures to 0.** Its `measure_*` checks were computing
  status with an expression that returned `FAIL` for anything above threshold
  regardless of declared severity, so measurements like "28,785 distinct
  students" were reported as 28,785 failures. The status expression now matches
  Raw and Mart.
- **`domain_imd_band_format` cleared at Mart.** Clean now normalises `10-20` to
  `10-20%`, and Mart has been rebuilt since. 3,516 rows fixed. Mart's only
  remaining warning is `dim_course_exists`.

<br>

## 2. Where are the results

One table, all three layers.

```
`ftw-week-07`.`01-raw`.dq_check_results
```

Every check ever run is a row in it. The `layer` column separates Raw, Clean and
Mart. One table means one dashboard covers the whole pipeline rather than three
disconnected reports.

A view, `v_dq_latest`, filters to the most recent run per layer. Dashboard tiles
read the view; exit gates read a specific `run_id`.

<br>

## 3. The results table, column by column

| Column | Meaning |
|---|---|
| `run_id` | UUID generated once per notebook run. Groups all checks from one execution. |
| `executed_at` | When this check ran. |
| `layer` | `raw`, `clean`, or `mart`. |
| `dataset` | Which table was checked. |
| `check_name` | Unique name for the check. This is the idempotency key. |
| `check_type` | Category — see section 5. |
| `status` | What happened this run: `PASS`, `WARN`, `FAIL`, `INFO`. |
| `severity` | What a violation *means*: `FAIL`, `WARN`, `INFO`. |
| `fail_count` | Rows that violated the check. |
| `total_count` | Rows in the dataset. |
| `fail_pct` | `fail_count / total_count`. |
| `threshold_pct` | Share of rows that may fail before the severity applies. |
| `metric_value` | A measured quantity. Never a failure count. |
| `owner` | Who acts if it fails. |
| `details` | What the check tests and what to do about it. |

<br>

## 4. Status vs Severity

Two different things, and keeping them separate is what makes the dashboard
readable.

**Severity is declared when the check is written.** *If this is violated, does
the pipeline stop?*

**Status is computed when the check runs.** *What happened this time?*

```sql
CASE WHEN severity = 'INFO'                          THEN 'INFO'
     WHEN fail_count = 0                             THEN 'PASS'
     WHEN fail_count / total_count <= threshold_pct  THEN 'WARN'
     ELSE severity END
```

Measurements are always INFO; a clean check passes; a violation within tolerance
warns; a violation beyond tolerance takes whatever severity the check declared.

Without the split, a dashboard cannot answer *"do we need to stop?"* separately
from *"is anything unusual?"*, every issue looks equally urgent. The Clean
layer's 9 phantom failures were exactly this: an expression that collapsed
severity into status.

| Status | Meaning | Action |
|---|---|---|
| `PASS` | Expectation held | None |
| `WARN` | Known issue, quantified and documented | Review, don't block |
| `FAIL` | Expectation broken | **Stop. Do not build the next layer.** |
| `INFO` | A measurement, not a test | Excluded from pass rate |

<br>

## 5. Check types

| Type | Question it answers |
|---|---|
| `UNIQUE` | Are the declared keys actually unique? |
| `NOT_NULL` | Are required columns populated? |
| `RANGE` | Are numeric values inside their valid bounds? |
| `DOMAIN` | Are categorical values from the expected set? |
| `REFERENTIAL` | Does every foreign key resolve to a real parent row? |
| `CONSISTENCY` | Do two columns that should agree, agree? |
| `RECONCILIATION` | Does a total match the layer below? |
| `VOLUME` | Is the row count plausible against the previous run? |
| `MEASURE` | A recorded quantity, not a pass/fail test |

<br>

## 6. Design choices, and why

### 6.1 Thresholds are fractions, not row counts

`threshold_pct` is a share of `total_count`, never a literal.

An early version used `WHEN COUNT(*) <= 50 THEN 'WARN'`, pinned to the 45 missing
registration dates out of 32,593 which is 0.138%. At ten times the volume the same rate
is 450 rows and the check fails for no reason.

**The test for any assertion: does it still hold when 5,000 new rows arrive
tomorrow?**

### 6.2 Nothing is hardcoded

Every expected value is computed from the layer below at runtime. The click
reconciliation does not contain the literal 39,605,099, it sums both sides and
compares.

### 6.3 History is never deleted

Each run gets a `run_id`. Re-running one cell deletes only that cell's rows *for
the current run*, so cells stay re-runnable while the trend survives. It is also
the only possible baseline for a VOLUME check.

### 6.4 Measurements are separated from failures

Quantities go in `metric_value` with `fail_count = 0` and status `INFO`, excluded
from the pass rate.

An early version stored the 39,605,099 click total in `fail_count`. The "failures
by dataset" tile would have reported 39.6 million failures on `student_vle`.

### 6.5 NULL means different things in different layers

- **At Raw**, `?` is the sentinel. A NULL would be a defect.
- **At Clean**, NULL is the *correct* representation of a missing value.

So a `NOT_NULL` check that is right at Raw is wrong at Clean. Clean uses
**conservation checks** instead: the Clean NULL count must equal the Raw `?`
count exactly. That fails only if the cast lost a value.

### 6.6 Each check deletes only its own rows

Scoped by `run_id + layer + check_name`, or `dataset` where a block writes
several checks. Two checks may share a `check_type`; no two may share a
`check_name`.

Learned from a live bug: `row_count_not_empty` and
`volume_stable_vs_previous_run` both had `check_type = 'VOLUME'`, so whichever
cell ran second silently erased the other's results while both reported a
successful insert.

### 6.7 Read warnings, not pass rate

**Pass rate rises for free as a suite grows.** Across Raw's runs it moved
89.8 → 91.2 → 92.3 while the source files never changed, the denominator grew
because VOLUME checks became scoreable and `row_count_not_empty` was added.

Warning and failure counts are the signal. Pass rate is context.

<br>

## 7. What each layer's checks answer

| Layer | Question | Typical checks |
|---|---|---|
| **Raw** | Did the file load? | Row counts vs source file, no rescued rows, keys unique, FKs resolve |
| **Clean** | Did the transformation preserve the data? | Null conservation, derived flags agree with source columns, row counts vs Raw |
| **Mart** | Does the star schema hold? | Declared grains unique, every FK resolves to a dimension, measures reconcile to source |

### Mart's two unique checks

**Grain uniqueness.** A grain statement in a comment is a claim.
`SELECT COUNT(*) FROM (... GROUP BY <grain> HAVING COUNT(*) > 1)` is the test.

**Foreign key resolution, checked twice.** A NULL FK means the join found
nothing. A *non-null* FK matching no dimension row means the dimensions were
rebuilt after the facts, `ROW_NUMBER()` reassigned every surrogate key.

That second failure is invisible to everything else: row counts unchanged, no
nulls, keys still unique, every answer quietly wrong. `fk_enrollment_resolves`
and `fk_site_resolves` are the only checks that catch it, and **they must be
re-run after any dimension rebuild.**

<br>

## 8. The headline result: end-to-end reconciliation

One measure, three layers, unchanged:

| Layer | Total clicks |
|---|---|
| `01-raw`.student_vle | 39,605,099 |
| `02-clean`.student_vle | 39,605,099 |
| `03-mart`.fact_activity | 39,605,099 |

10,655,280 session rows aggregated to 8,459,320 daily rows. **Zero clicks lost.**

This matters more than any row count. `student_vle` is the one table that is
*supposed* to shrink, so an expected reduction and silent data loss look
identical in a row count. The click total is the only thing that tells them
apart, and it survived the one transformation where the pipeline could have lost data.

<br>

### Querying results

Any query against `dq_check_results` needs a deliberate answer to *which run?*

| Want | Use |
|---|---|
| Current state | `FROM v_dq_latest` |
| A specific run | `WHERE run_id = '<uuid>'` |
| Trend over time | `GROUP BY run_id, layer` |

No filter at all is always wrong, and wrong in a way that looks plausible. The
all-layers tile currently reads `clean 855 / mart 345 / raw 584` because it
groups the base table, which holds every run ever. Point it at `v_dq_latest`.

<br>

## 9. What "validated" means here

The gates are queries, not enforced controls. Nothing technically prevents
someone building Mart on a red Clean layer. That is acceptable for a project this
size as long as it is stated rather than assumed.

What the framework does establish: every row is accounted for at every layer
boundary, every NULL traces back to a sentinel in the source, every declared
grain has been tested rather than asserted, every foreign key resolves, and one
real business measure reconciles from the source CSV through to the star schema.
