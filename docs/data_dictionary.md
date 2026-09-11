# OULAD Data Dictionary

This section documents the structure, grain, data types, and meaning of the tables in the ingested raw layer.

## Ingested Raw Tables

| Table | Grain — What Each Row Represents | Column | Data Type | Description |
|---|---|---|---|---|
| **assessments** | **One assessment within a module presentation** | `code_module` | STRING | Identifies the module/course. Example: `AAA` |
| | | `code_presentation` | STRING | Identifies the specific presentation of the module. Example: `2013B` |
| | | `id_assessment` | INT | Unique identifier for the assessment |
| | | `assessment_type` | STRING | Type of assessment: `TMA`, `CMA`, or `Exam` |
| | | `date` | STRING* | Number of days from the start of the module until the assessment deadline |
| | | `weight` | DOUBLE | Percentage contribution of the assessment to the final grade |
| **courses** | **One module presentation** | `code_module` | STRING | Identifies the module/course |
| | | `code_presentation` | STRING | Identifies the specific presentation of the module |
| | | `module_presentation_length` | INT | Number of days the module presentation lasts |
| **student_assessment** | **One student's result for one assessment** | `id_assessment` | INT | Identifies the assessment |
| | | `id_student` | INT | Identifies the student |
| | | `date_submitted` | INT | Number of days from the module start when the student submitted the assessment |
| | | `is_banked` | INT | Indicates whether the assessment result was carried forward from a previous attempt. `0` = No, `1` = Yes |
| | | `score` | STRING* | Student's assessment score, generally from 0 to 100 |
| **student_info** | **One student in one module presentation** | `code_module` | STRING | Identifies the module the student is enrolled in |
| | | `code_presentation` | STRING | Identifies the presentation of the module |
| | | `id_student` | INT | Identifies the student |
| | | `gender` | STRING | Student's recorded gender |
| | | `region` | STRING | Region where the student lives |
| | | `highest_education` | STRING | Student's highest recorded education level |
| | | `imd_band` | STRING | Student's Index of Multiple Deprivation band |
| | | `age_band` | STRING | Student's age group |
| | | `num_of_prev_attempts` | INT | Number of previous attempts at the module |
| | | `studied_credits` | INT | Number of credits the student is studying |
| | | `disability` | STRING | Indicates whether the student has declared a disability. `n` = No, `y` = Yes |
| | | `final_result` | STRING | Student's final result for the module: `distinction`, `pass`, `fail`, or `withdrawn` |
| **student_registration** | **One student's registration for one module presentation** | `code_module` | STRING | Identifies the module the student registered for |
| | | `code_presentation` | STRING | Identifies the presentation of the module |
| | | `id_student` | INT | Identifies the student |
| | | `date_registration` | STRING* | Number of days before or after the module start when the student registered |
| | | `date_unregistration` | STRING* | Number of days before or after the module start when the student withdrew. Can be missing |
| **student_vle** | **One student's interaction with one VLE resource on one day** | `code_module` | STRING | Identifies the module the student is taking |
| | | `code_presentation` | STRING | Identifies the presentation of the module |
| | | `id_student` | INT | Identifies the student |
| | | `id_site` | INT | Identifies the VLE resource/activity |
| | | `date` | STRING* | Number of days from the module start when the interaction occurred. `date = 0` = day the module started; `date < 0` = interactions that occurred before day 0 |
| | | `sum_click` | INT | Number of recorded interactions with the VLE resource on that day |
| **vle** | **One VLE resource/activity** | `id_site` | INT | Unique identifier for a VLE resource/activity |
| | | `code_module` | STRING | Identifies the module associated with the resource |
| | | `code_presentation` | STRING | Identifies the presentation associated with the resource |
| | | `activity_type` | STRING | Type of VLE activity/resource, such as `resource`, `forum`, or `quiz` |
| | | `week_from` | STRING* | Week when the activity becomes available |
| | | `week_to` | STRING* | Week when the activity stops being available |

> **Important Note:** Columns marked with `*` are not explicitly cast during ingestion. Their data type may therefore remain `STRING`, depending on Databricks `read_files` type inference. The actual schema should be verified using `DESCRIBE TABLE` before finalizing the data types in the documentation.

---

## Table Grain Summary

| Table | Grain |
|---|---|
| `courses` | One **module presentation** |
| `assessments` | One **assessment** within a module presentation |
| `student_assessment` | One **student's result for one assessment** |
| `student_info` | One **student enrolled in one module presentation** |
| `student_registration` | One **student's registration for one module presentation** |
| `vle` | One **VLE resource/activity** |
| `student_vle` | One **student's interaction with one VLE resource on one day** |
