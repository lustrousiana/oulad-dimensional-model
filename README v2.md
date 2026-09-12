# OULAD Learning Analytics Pipeline

A Databricks/Delta Lake pipeline that transforms the Open University Learning
Analytics Dataset (OULAD) into a dimensional model for analyzing student
engagement, performance, and withdrawal.

## Business questions

This pipeline exists to answer three questions:

1. How does student engagement (VLE activity) relate to performance (assessment scores)?
2. What patterns appear among students who withdraw?
3. How does student activity change throughout a course?
4. Which assessment types modules have the highest failure rates? (Bonus)


## Architecture

Medallion architecture

```
Source CSVs (Cloudflare R2 volume)
        │
        ▼
  00-source     (landing volume — courses, assessments, vle, studentInfo,
                 studentRegistration, studentAssessment, studentVle)
        │
        ▼
  01-raw        Bronze. As-is load, all columns STRING, COPY INTO with
                _rescued_data + lineage columns. Reconciled against source
                line counts in _ingest_audit.
        │
        ▼
  02-clean      Silver. Typed, '?' sentinels converted to NULL, dedup
                applied (student_vle), quality-flag columns added
                (has_missing_due_date, had_multiple_records,
                is_late_submission, had_withdrawal_corrected, etc.)
        │
        ▼
  03-mart       Gold. Dimensions + facts, hand-written SQL
                (CREATE OR REPLACE TABLE ... AS SELECT).
        │
        ▼
  04-analytics  BI-facing views/aggregates. First table in progress:
                `student_engagement_performance` (answers Q1).
```

Every check across every layer logs to one shared `dq_check_results` table,
scoped by `run_id` + `layer` + `dataset` + `check_name`, so results are
comparable across layers and across runs (see Data quality approach below).


## Data model (mart layer)

The implemented mart is a wide-dimension, two-fact model — simpler than the
conceptual 3-fact / 2-fact designs explored earlier in this project (kept in
`docs/` for reference), because it folds course attributes, demographics, and
enrollment lifecycle into one dimension rather than conforming them separately.

**Dimensions**
| Table |
|---|
| `dim_student_enrollment` |
| `dim_assessment` |
| `dim_site` |

**Facts**
| Table | Grain | Answers |
|---|---|---|
| `fact_assessment` | student enrollment × assessment | Q1 |
| `fact_activity` | student enrollment × VLE site × activity date | Q1, Q3 |

Withdrawal analysis (Q2) reads directly off `dim_student_enrollment`
(`final_result`, `date_unregistration`) rather than a separate fact, since
enrollment is already the dimension's grain.

┌───────────────────────────────── ──┐
│      DIM_STUDENT_ENROLLMENT        │
├───┬────────────────────────────── ─┤
│PK │ student_enrollment_key   INT   │
│   │ id_student               INT   │
│   │ code_module              STRING│
│   │ code_presentation        STRING│
│   │ gender                   STRING│
│   │ region                   STRING│
│   │ highest_education        STRING│
│   │ imd_band                 STRING│
│   │ age_band                 STRING│
│   │ num_of_prev_attempts     INT   │
│   │ studied_credits          INT   │
│   │ disability               STRING│
│   │ final_result             STRING│
│   │ date_registration        INT   │
│   │ date_unregistration      INT   │
└───┴─────────────────────────────── ┘
        △                     △
        │                     │
┌───────┴─────────  ┐  ┌───────┴─────────┐
│  FACT_ASSESSMENT  │  │  FACT_ACTIVITY  │
├───┬───────────── ─┤  ├───┬─────────────┤
│PK │fact_assessment│  │PK │fact_activity │
│   │  _key    INT  │  │   │  _key   INT  │
│FK │student_enroll-│  │FK │student_enroll-│
│   │  ment_key INT │  │   │  ment_key INT│
│FK │assessment_key │  │FK │site_key  INT │
│   │  INT          │  │   │activity_date │
│   │date_submitted │  │   │  INT         │
│   │  INT          │  │   │total_clicks  │
│   │is_banked  INT │  │   │  INT         │
│   │score   DOUBLE │  └───┴─────────── ──┘
└───┴──────────────┘            △
        △                       │
        │               ┌───────┴─────────┐
┌───────┴──────── ──┐   │     DIM_SITE    │
│   DIM_ASSESSMENT  │   ├───┬─────────────┤
├───┬───────────────┤   │PK │site_key INT │
│PK │assessment_key │   │   │id_site  INT │
│   │  INT          │   │   │code_module  │
│   │id_assessment  │   │   │  STRING     │
│   │  INT          │   │   │code_presen- │
│   │assessment_type│   │   │  tation     │
│   │  STRING       │   │   │  STRING     │
│   │due_day_offset │   │   │activity_type│
│   │  INT          │   │   │  STRING     │
│   │weight  DOUBLE │   └───┴─────────────┘
└───┴───────────────┘

## Repository structure

Repo: `oulad-dimensional-model` (Workspace ▸ Shared)

```
├── dashboard/                    # DQ health dashboard (v_dq_latest tiles)
├── docs/
│   ├── data_architecture.md      # how data moves through the pipeline   
│   ├── data_dictionary.md        # raw-layer column definitions
│   └── data_quality_check.md     # raw DQ check results follwing 6 categories
├── src/sql/
│   ├── 01-raw/                   # bronze ingestion (COPY INTO + audit)
│   ├── 02-clean/                 # silver cleaning/typing
│   ├── 03-mart/                  # gold dimensions + facts
│   └── 04-analytics/             # analytics queries (e.g. Q1 engagement vs performance)
├── tests/
│   ├── 01_raw_data_checks/
│   ├── 02_clean_data_checks/
│   └── 03_mart_data_checks/
└── README.md
```


## Running the pipeline

1. Run `src/sql/01-raw/` — lands source CSVs as bronze tables, writes
   `_ingest_audit` reconciliation rows, then runs raw-layer DQ checks
2. **Raw exit gate**: query `dq_check_results` for `status = 'FAIL'` at
   `layer = 'raw'`. Clean does not start until this returns zero rows.
3. Run `src/sql/02-clean/` — types, cleans, dedupes, flags quality issues
4. Run `src/sql/03-mart/` — rebuilds dimensions and facts via
   `CREATE OR REPLACE TABLE ... AS SELECT`
5. Run `src/sql/04-analytics/` for downstream aggregates (e.g. Q1's
   `student_engagement_performance`)
6. Check `dashboard/` (or query `v_dq_latest`) to confirm overall health
   before treating mart tables as trustworthy

## Data quality approach

One shared `dq_check_results` table covers every dataset at every layer.
Each dataset's check block follows the same pattern: `DELETE` this run's
prior rows for that `layer`/`dataset` scope, then `INSERT` one row per check
via a `checks` CTE.

`v_dq_latest` view holds the most recent run per layer; six dashboard tiles (overall health, failures by dataset, failures by check type, open issues ranked by severity, measurements, and a pass-rate trend over time) all read from it.
