# Data Architecture

This document describes how data moves and transforms through the OULAD
pipeline, layer by layer. For project orientation (business questions, repo
layout, how to run it), see `README.md`.

## 1. Overview

Medallion architecture on Databricks / Unity Catalog / Delta Lake. Five
layers, each a schema under catalog **`ftw-week-07`**:

```
00-source  →  01-raw  →  02-clean  →  03-mart  →  04-analytics
(landing)     (bronze)    (silver)     (gold)      (not yet built)
```


## 2. Layer 0 — Source (`00-source`)

Source CSVs arrive here from Cloudflare R2 at
`/Volumes/<catalog>/00-source/cloudflare-r2/`. Nothing is transformed at
this layer — it exists purely so `01-raw` has a stable, version-controlled
place to read from.

## 3. Layer 1 — Raw (`01-raw`)

Bronze principle: load as-is.

**Ingestion pattern**, repeated per dataset (declare → copy → reconcile):

1. `CREATE TABLE IF NOT EXISTS` with all source columns as `STRING`, plus
   four lineage columns: `_rescued_data`, `_source_file`,
   `_source_modified_at`, `_ingested_at`.
2. `COPY INTO` from the source volume, `FORMAT_OPTIONS` set with
   `rescuedDataColumn = '_rescued_data'` — any row with unexpected extra
   columns lands its overflow there instead of failing the load.
3. An `INSERT INTO _ingest_audit` reconciliation: physical line count of the
   source file (minus header) vs. rows actually loaded. `row_delta` must be
   zero; a mismatch is a `FAIL`, and any rescued rows are a `WARN`.


**Data quality**: every raw table gets a check block (see §6) written to a
shared `dq_check_results` log, scoped `layer = 'raw'`. A `FAIL` at this
layer blocks Clean from running — see the raw exit gate in `README.md`.

## 4. Layer 2 — Clean (`02-clean`)

Silver principle: type it, name the sentinels, flag what you can't fix.

Each raw table gets one clean counterpart, built with
`CREATE OR REPLACE TABLE ... AS SELECT` (full rebuild every run, not an
incremental upsert). The transformation per table:

| Table | What changes |
|---|---|
| `courses` | Cast `module_presentation_length` to `INT`; derive `presentation_year` and `presentation_season` from `code_presentation` (e.g. `2013B` → year 2013, season B) |
| `assessments` | `date` **renamed to `due_day_offset`** for clarity; `'?'` → `NULL`, flagged by `has_missing_due_date` (12 rows); new `has_invalid_weight_sum` flag (presentation-level assessment weights that don't sum to 100%) |
| `student_assessment` | Adds `is_submitted` and `is_late_submission` (compares `date_submitted` to `assessments.due_day_offset`) |
| `student_info` | `gender`/`disability` upper-cased, `final_result` title-cased, `'?'` in `imd_band` → `NULL` (flag `has_missing_imd_band`). **New business rule**: `final_result` is corrected to `'Withdrawn'` whenever `date_unregistration` is present but source didn't already say Withdrawn (102 rows), flagged by `had_withdrawal_corrected` — `date_unregistration` is treated as the authoritative signal over the source's own label |
| `student_registration` | `'?'` → `NULL` via `TRY_CAST` in both date columns; derives `enrollment_duration_days` and `completed_course`. Negative `date_registration` values (32,312 rows) are **valid** — students can register before day 0 |
| `student_vle` | Aggregated: 999 duplicate `(student, site, date)` combinations (1,404 rows) collapsed via `SUM(sum_click) GROUP BY` the natural key, flagged by `had_multiple_records` (renamed from `was_deduplicated` — the source rows may be repeat sessions, not strict duplicates) |
| `vle` | `'?'` in `week_from`/`week_to` → `NULL` (5,243 rows each — "always-on" resources with no defined availability window), flagged by `has_missing_week_boundaries` |

The recurring pattern: every column that had a `'?'` sentinel in source gets
a companion `BOOLEAN` quality-flag column rather than silently dropping or
imputing the value — downstream consumers decide how to handle it per
analysis instead of the pipeline deciding for them. All casts now use
`TRY_CAST` rather than `CAST`, so an unexpected non-numeric value becomes
`NULL` instead of failing the whole transform.

A validation block at the end of Clean cross-checks row counts against Raw
(accounting for the one dataset that legitimately shrinks — deduplication —
and flags others that should match exactly).

**Data quality**: clean-layer checks (`layer = 'clean'`) focus on things raw
couldn't check yet — referential integrity, uniqueness at the intended
grain, and business rules like `date_unregistration >= date_registration`.

## 5. Layer 3 — Mart (`03-mart`)

Gold principle: model and tables for the business questions.

Built with
`CREATE OR REPLACE TABLE ... AS SELECT` from Clean. Surrogate keys are
generated with `ROW_NUMBER() OVER (ORDER BY ...)` on the natural key.

**Dimensions**

| Table | Grain | Built from |
|---|---|---|
| `dim_student_enrollment` | one row per student per course presentation | `student_info` LEFT JOIN `student_registration` |
| `dim_assessment` | one row per assessment definition | `assessments` (column is `due_day_offset`; latest ERD image still labels it `date` — diagram is stale) |
| `dim_site` | one row per VLE site | `vle` |

**Facts**

| Table | Grain | Built from | Join notes |
|---|---|---|---|
| `fact_assessment` | student enrollment × assessment | `student_assessment` | INNER JOIN to `dim_assessment` (every assessment must resolve); **LEFT JOIN** to `dim_student_enrollment` — `student_enrollment_key` is nullable because banked assessments (re-used scores from a prior presentation) don't always resolve to a current enrollment |
| `fact_activity` | student enrollment × VLE site × activity date | `student_vle` | LEFT JOIN to both `dim_student_enrollment` and `dim_site` |

This is a wide-dimension, two-fact design — it folds course attributes,
demographics, and enrollment lifecycle into one dimension rather than
conforming them separately into `dim_course`/`dim_date`/`dim_final_result`,
which earlier design exploration in this project had proposed. See the ERD
in `README.md` for the current shape.

**Data quality**: mart-layer checks (`layer = 'mart'`) verify the star
schema itself — every fact FK resolves (except the known-nullable one
above), grain uniqueness holds on the surrogate key, and row-count
reconciliation against Clean accounts for any fan-out from the joins.

## 6. Layer 4 — Analytics (`04-analytics`)

BI-facing views/aggregates on top of the mart layer. First table now built:
`student_engagement_performance` (answers Q1) — one row per
`student_enrollment_key`, joining clicks/active-days from `fact_activity`
against average/min/max score from `fact_assessment`. Written as plain SQL
(`src/sql/04-analytics/`, hardcoded `` `ftw-week-07` `` catalog).

## 7. Cross-cutting: the data quality framework

One log table, `dq_check_results`, covers every dataset at every layer. 

- Every check run gets a `run_id` (UUID). Re-running a dataset's check block
  deletes only that `run_id`'s prior rows for that `layer`/`dataset`, so
  reruns are idempotent but history across runs is preserved.
- `check_type` taxonomy: `NOT_NULL`, `UNIQUE`, `RANGE`, `DOMAIN`,
  `REFERENTIAL`, `VOLUME`, `FORMAT`, `CONSISTENCY`, `RECONCILIATION`,
  `MEASURE`.
- `status` (`PASS`/`WARN`/`FAIL`/`INFO`) is derived at insert time from
  `fail_count`, `total_count`, and a per-check `threshold_pct` — not
  hardcoded per check.
- **Raw exit gate**: any `FAIL` at `layer = 'raw'` stops the pipeline before
  Clean runs.
- All three layers (`raw`, `clean`, `mart`) now write to the same
  `dq_check_results` table with the same 15 columns and status logic —
  confirmed by `mart_dq_check.ipynb` — so the dashboard covers all three
  with no changes needed.
- `v_dq_latest` (most recent run per layer) feeds six dashboard tiles:
  overall health, failures by dataset, failures by check type, open issues
  ranked by severity, measurements/reconciliation values, and a pass-rate
  trend over time.
- The raw-layer notebook ends with a self-test: it injects known-bad probe
  values (`0`, `?`, `abc`) into a check and confirms the check actually
  fails on them — catching the case where a check silently stops working.

## 8. Naming conventions

- Layer schemas are numerically prefixed (`00-source` … `04-analytics`) so
  they sort in pipeline order in the catalog browser.
- Raw-layer lineage columns are `_`-prefixed (`_rescued_data`,
  `_source_file`, `_source_modified_at`, `_ingested_at`) so they can be
  dropped in bulk with `SELECT * EXCEPT (...)`.
- Data-quality flag columns in Clean follow `has_missing_<field>` or
  `was_<action>` (e.g. `has_missing_imd_band`, `was_deduplicated`).
- The DQ run variable is named `dq_run_id` / `ingest_batch_id` deliberately
  different from the `run_id` column it filters against — an unqualified
  reference matching a column name resolves to the column, which would
  silently turn a `WHERE run_id = run_id` filter into a no-op.

