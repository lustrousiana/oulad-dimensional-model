# OULAD Raw Data Quality Check

This document presents the results of the data quality checks performed on the OULAD dataset before data transformation and dimensional modeling.

The following six categories were evaluated for each table:

1. **Null** – identifies missing or source-level missing values.
2. **Unique** – checks for duplicate records based on the expected key.
3. **Range** – verifies whether numeric values fall within valid ranges.
4. **Accepted Values** – verifies categorical values against expected values.
5. **Referential Integrity** – verifies relationships between related tables.
6. **Volume** – records the number of rows loaded.

> **Note:** Some values that appear unusual are valid characteristics of the OULAD dataset. In particular, negative date values represent day offsets relative to the start of a course presentation. The `?` character represents missing values in the original source data.

---

## Data Quality Check Results

| Table | Null | Unique | Range | Accepted Values | Referential Integrity | Volume |
|---|---|---|---|---|---|---|
| **`assessments`** | 206 rows loaded. No null values found. 12 `?` values found in `date`. | No duplicate `id_assessment` values. All 206 assessment IDs are unique. | `weight`: 0–100. No negative weights or assessment IDs. No invalid numeric date values. | `assessment_type`: `CMA`, `TMA`, `Exam`. | All `code_module` + `code_presentation` combinations exist in `courses`. | **206 rows** |
| **`courses`** | No null values found. | No duplicate course presentations found. | Course length: 234–269 days. No invalid course lengths found. | `code_module`: `AAA`, `BBB`, `CCC`, `DDD`, `EEE`, `FFF`, `GGG`.<br>`code_presentation`: `2013B`, `2013J`, `2014B`, `2014J`. | All assessment course combinations exist in `courses`. 0 unmatched combinations. | **22 rows** |
| **`student_assessment`** | No null values found in `id_assessment`, `id_student`, `date_submitted`, `is_banked`, or `score`. | No duplicate `id_assessment` + `id_student` combinations. 0 duplicate records. | `date_submitted`: -11–608.<br>`is_banked`: 0–1.<br>`score`: 0–100. No invalid scores found. | `is_banked`: `0`, `1`. | All `id_assessment` values exist in `assessments`. 0 unmatched assessment IDs. | **173,912 rows** |
| **`student_info`** | No null values found. 1,111 `?` values found in `imd_band`, representing missing source values. | No duplicate `code_module` + `code_presentation` + `id_student` combinations. 0 duplicate records. | `num_of_prev_attempts`: 0–6.<br>`studied_credits`: 30–655.<br>No negative values found. | `gender`: `F`, `M`.<br>`region`: expected 13 regions.<br>`highest_education`: 5 expected values.<br>`imd_band`: expected bands + `?`.<br>`age_band`: `0-35`, `35-55`, `55<=`.<br>`disability`: `N`, `Y`.<br>`final_result`: `Distinction`, `Fail`, `Pass`, `Withdrawn`. | All `code_module` + `code_presentation` combinations exist in `courses`. 0 unmatched combinations. | **32,593 rows** |
| **`student_registration`** | No null values found. | No duplicate `code_module` + `code_presentation` + `id_student` combinations. 0 duplicate records. | `date_registration`: -322–167.<br>`date_unregistration`: -365–444.<br>32,312 negative `date_registration` values found. Negative values are valid OULAD day offsets. | `code_module`: `AAA`, `BBB`, `CCC`, `DDD`, `EEE`, `FFF`, `GGG`.<br>`code_presentation`: `2013B`, `2013J`, `2014B`, `2014J`.<br>No unexpected values found. | All `code_module` + `code_presentation` combinations exist in `courses`. 0 unmatched combinations. | **32,593 rows** |
| **`student_vle`** | No null values found. No `?` values found in `date`. | 999 duplicate `code_module` + `code_presentation` + `id_student` + `id_site` + `date` combinations found, representing 1,404 additional rows. Duplicates require investigation before removal. | `date`: -25–269.<br>`sum_click`: 1–6,977.<br>No negative `sum_click` values. Negative dates are valid OULAD day offsets. | `code_module`: `AAA`, `BBB`, `CCC`, `DDD`, `EEE`, `FFF`, `GGG`.<br>`code_presentation`: `2013B`, `2013J`, `2014B`, `2014J`. | All course combinations exist in `courses`. All `id_site` values exist in `vle`. 0 unmatched course presentations or site IDs. | **10,655,280 rows** |
| **`vle`** | No null values found. 5,243 `?` values found in `week_from` and 5,243 `?` values in `week_to`. | No duplicate `id_site` values. Each `id_site` is unique. | `week_from`: 0–29.<br>`week_to`: 0–29.<br>No unexpected numeric ranges found. | `activity_type`: expected 20 activity types.<br>`code_module`: `AAA`, `BBB`, `CCC`, `DDD`, `EEE`, `FFF`, `GGG`.<br>`code_presentation`: `2013B`, `2013J`, `2014B`, `2014J`. | All `code_module` + `code_presentation` combinations exist in `courses`. 0 unmatched course presentations. | **6,364 rows** |

---

## Data Quality Notes

### Source-Level Missing Values

The OULAD source uses `?` to represent missing values in some fields.

The following were identified:

| Table | Column | Missing Source Values |
|---|---|---:|
| `assessments` | `date` | 12 |
| `student_info` | `imd_band` | 1,111 |
| `vle` | `week_from` | 5,243 |
| `vle` | `week_to` | 5,243 |

During transformation, these values should be standardized to `NULL` rather than interpreted as valid categorical or numeric values.

### Negative Date Values

Negative dates are valid in OULAD because dates are represented as **relative day offsets from the start of a course presentation**.

For example:

```text
-10  → 10 days before the course presentation starts
  0  → course presentation start
+10  → 10 days after the course presentation starts
