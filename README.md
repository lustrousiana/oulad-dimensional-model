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
                (has_missing_date, was_deduplicated, is_late_submission, etc.)
        │
        ▼
  03-mart       Gold. Dimensions + facts (see Data model below).
        │
        ▼
  04-analytics  Reserved for BI-facing views/aggregates. Not yet built.
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


```mermaid
    DIM_STUDENT_ENROLLMENT {
        int student_enrollment_key PK
        int id_student
        string code_module
        string code_presentation
        string gender
        string highest_education
        string imd_band
        string age_band
        int num_of_prev_attempts
        int studied_credits
        string final_result
        string disability
        int date_registration
        int date_unregistration
    }
    DIM_ASSESSMENT {
        int assessment_key PK
        int id_assessment
        string assessment_type
        int date
        double weight
    }
    DIM_SITE {
        int site_key PK
        int id_site
        string activity_type
    }
    FACT_ASSESSMENT {
        int fact_assessment_key PK
        int assessment_key FK
        int student_enrollment_key FK
        int date_submitted
        boolean is_banked
        double score
    }
    FACT_ACTIVITY {
        int fact_activity_key PK
        int student_enrollment_key FK
        int site_key FK
        int activity_date
        int total_clicks
    }

    DIM_STUDENT_ENROLLMENT ||--o{ FACT_ASSESSMENT : "has"
    DIM_ASSESSMENT ||--o{ FACT_ASSESSMENT : "has"
    DIM_STUDENT_ENROLLMENT ||--o{ FACT_ACTIVITY : "has"
    DIM_SITE ||--o{ FACT_ACTIVITY : "has"
```

## Repository structure

```
├── dashboard/                    # DQ health dashboard (v_dq_latest tiles)
├── docs/
│   └── decisions.md              # known data issues, accepted trade-offs
├── src/sql/
│   ├── 01-raw/                   # bronze ingestion (COPY INTO + audit)
│   ├── 02-clean/                 # silver cleaning/typing
│   └── 03-mart/                  # gold dimensions + facts
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
5. Check `dashboard/` (or query `v_dq_latest`) to confirm overall health
   before treating mart tables as trustworthy

## Data quality approach

One shared `dq_check_results` table covers every dataset at every layer.
Each dataset's check block follows the same pattern: `DELETE` this run's
prior rows for that `layer`/`dataset` scope, then `INSERT` one row per check
via a `checks` CTE.

`v_dq_latest` view holds the most recent run per layer; six dashboard tiles (overall health, failures by dataset, failures by check type, open issues ranked by severity, measurements, and a pass-rate trend over time) all read from it.
