-- ============================================================================
-- OULAD :: SILVER CLEANING
-- Target: catalog `ftw-week-07`, schema `02-clean`
-- Source: `01-raw` (populated by data_ingestion.sql)
--
-- Production silver layer transformation pipeline
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS `ftw-week-07`.`02-clean`
COMMENT 'Silver layer. Cleaned and typed data with quality flags.';


-- ============================================================================
-- ASSESSMENTS - Clean version
-- ============================================================================
-- Issues addressed:
--   - 12 '?' values in date field converted to NULL
--   - Renamed 'date' to 'due_day_offset' for clarity (negative values are valid offsets)
--   - All validation checks passed (no duplicates, valid ranges, referential integrity)

CREATE OR REPLACE TABLE `ftw-week-07`.`02-clean`.assessments (
    id_assessment INT COMMENT 'Unique assessment identifier',
    code_module STRING COMMENT 'Module code (aaa-ggg)',
    code_presentation STRING COMMENT 'Presentation code (YYYY + B/J)',
    assessment_type STRING COMMENT 'Type: CMA, TMA, or Exam',
    due_day_offset INT COMMENT 'Day offset from course start when assessment is due (can be negative; NULL if unknown)',
    weight DOUBLE COMMENT 'Assessment weight in final grade (0-100)',
    has_missing_due_date BOOLEAN COMMENT 'Data quality flag: TRUE if due date was missing in source'
)
COMMENT 'Clean assessment definitions with data quality flags';

INSERT INTO `ftw-week-07`.`02-clean`.assessments
SELECT 
    id_assessment,
    code_module,
    code_presentation,
    assessment_type,
    -- Transform: Convert string to INT, '?' becomes NULL, invalid values also become NULL via TRY_CAST
    CASE WHEN date = '?' THEN NULL ELSE TRY_CAST(date AS INT) END AS due_day_offset,
    weight,
    -- Quality Flag: Track if source explicitly marked as missing with '?' (not other corrupt values)
    CASE WHEN date = '?' THEN TRUE ELSE FALSE END AS has_missing_due_date
FROM `ftw-week-07`.`01-raw`.assessments;


-- ============================================================================
-- COURSES - Clean version
-- ============================================================================
-- Issues addressed:
--   - All validation checks passed (no issues found)
--   - Added descriptive comments for documentation

CREATE OR REPLACE TABLE `ftw-week-07`.`02-clean`.courses (
    code_module STRING COMMENT 'Module code (aaa-ggg)',
    code_presentation STRING COMMENT 'Presentation code (YYYY + B/J: B=February, J=October)',
    module_presentation_length INT COMMENT 'Course duration in days (234-269)',
    presentation_year INT COMMENT 'Extracted year from code_presentation',
    presentation_season STRING COMMENT 'Extracted season: B (February) or J (October)'
)
COMMENT 'Clean course presentation definitions with derived fields';

INSERT INTO `ftw-week-07`.`02-clean`.courses
SELECT 
    code_module,
    code_presentation,
    module_presentation_length,
    CAST(SUBSTRING(code_presentation, 1, 4) AS INT) AS presentation_year,
    SUBSTRING(code_presentation, 5, 1) AS presentation_season
FROM `ftw-week-07`.`01-raw`.courses;


-- ============================================================================
-- STUDENT_ASSESSMENT - Clean version
-- ============================================================================
-- Issues addressed:
--   - All validation checks passed (no issues found)
--   - Added calculated fields for analysis
--   - is_banked flag already clean (0 or 1)

CREATE OR REPLACE TABLE `ftw-week-07`.`02-clean`.student_assessment (
    id_assessment INT COMMENT 'Assessment identifier',
    id_student INT COMMENT 'Student identifier',
    date_submitted INT COMMENT 'Day offset when submitted (can be negative if early)',
    is_banked INT COMMENT 'Whether result was banked from previous presentation (0=No, 1=Yes)',
    score DOUBLE COMMENT 'Assessment score (0-100, NULL if not graded)',
    is_submitted BOOLEAN COMMENT 'TRUE if student submitted (all records represent submissions; NULL score means not yet graded)',
    is_late_submission BOOLEAN COMMENT 'TRUE if submitted after due date'
)
COMMENT 'Clean student assessment submissions with derived flags';

INSERT INTO `ftw-week-07`.`02-clean`.student_assessment
SELECT 
    sa.id_assessment,
    sa.id_student,
    sa.date_submitted,
    sa.is_banked,
    -- Transform: Convert score string to DOUBLE, '?' becomes NULL, invalid values also become NULL via TRY_CAST
    CASE WHEN sa.score = '?' THEN NULL ELSE TRY_CAST(sa.score AS DOUBLE) END AS score,
    -- Hardcoded: All records represent submissions (presence in table = submission occurred)
    TRUE AS is_submitted,
    -- Calculated: Flag late submissions by comparing submission date to due date
    CASE 
        WHEN a.due_day_offset IS NOT NULL AND sa.date_submitted > a.due_day_offset THEN TRUE 
        ELSE FALSE 
    END AS is_late_submission
FROM `ftw-week-07`.`01-raw`.student_assessment sa
LEFT JOIN `ftw-week-07`.`02-clean`.assessments a
    ON sa.id_assessment = a.id_assessment;


-- ============================================================================
-- STUDENT_INFO - Clean version
-- ============================================================================
-- Issues addressed:
--   - 1,111 '?' values in imd_band converted to NULL
--   - 3,516 '10-20' values standardized to '10-20%' (format consistency)
--   - Standardized categorical values to uppercase
--   - Added data quality flag for missing deprivation band

CREATE OR REPLACE TABLE `ftw-week-07`.`02-clean`.student_info (
    id_student INT COMMENT 'Unique student identifier',
    code_module STRING COMMENT 'Module code',
    code_presentation STRING COMMENT 'Presentation code',
    gender STRING COMMENT 'Student gender (M or F)',
    region STRING COMMENT 'Geographic region (13 UK regions)',
    highest_education STRING COMMENT 'Highest education level attained',
    imd_band STRING COMMENT 'Index of Multiple Deprivation band (NULL if unknown)',
    age_band STRING COMMENT 'Age group (0-35, 35-55, 55<=)',
    num_of_prev_attempts INT COMMENT 'Number of previous attempts (0-6)',
    studied_credits INT COMMENT 'Total credits studied (30-655)',
    disability STRING COMMENT 'Has disability (Y or N)',
    final_result STRING COMMENT 'Course outcome (Pass, Fail, Distinction, Withdrawn)',
    has_missing_imd_band BOOLEAN COMMENT 'Data quality flag: TRUE if deprivation band unknown'
)
COMMENT 'Clean student demographic and outcome data with data quality flags';

INSERT INTO `ftw-week-07`.`02-clean`.student_info
SELECT 
    id_student,
    code_module,
    code_presentation,
    UPPER(gender) AS gender,
    region,
    highest_education,
    -- Transform: Convert '?' to NULL, standardize '10-20' format to '10-20%', keep valid values
    CASE 
        WHEN imd_band = '?' THEN NULL
        WHEN imd_band = '10-20' THEN '10-20%'
        ELSE imd_band 
    END AS imd_band,
    age_band,
    num_of_prev_attempts,
    studied_credits,
    UPPER(disability) AS disability,
    INITCAP(final_result) AS final_result,
    -- Quality Flag: Track if source explicitly marked as missing with '?'
    CASE WHEN imd_band = '?' THEN TRUE ELSE FALSE END AS has_missing_imd_band
FROM `ftw-week-07`.`01-raw`.student_info;


-- ============================================================================
-- STUDENT_REGISTRATION - Clean version
-- ============================================================================
-- Issues addressed:
--   - All validation checks passed
--   - 32,312 negative date_registration values are VALID (day offsets)
--   - Added calculated enrollment duration

CREATE OR REPLACE TABLE `ftw-week-07`.`02-clean`.student_registration (
    id_student INT COMMENT 'Student identifier',
    code_module STRING COMMENT 'Module code',
    code_presentation STRING COMMENT 'Presentation code',
    date_registration INT COMMENT 'Day offset when registered (can be negative)',
    date_unregistration INT COMMENT 'Day offset when unregistered (NULL if completed)',
    enrollment_duration_days INT COMMENT 'Days between registration and unregistration',
    completed_course BOOLEAN COMMENT 'TRUE if student never unregistered'
)
COMMENT 'Clean student registration records with enrollment metrics';

INSERT INTO `ftw-week-07`.`02-clean`.student_registration
SELECT 
    id_student,
    code_module,
    code_presentation,
    -- Transform: Convert date strings to INT, '?' becomes NULL, invalid values also become NULL via TRY_CAST
    CASE 
        WHEN date_registration = '?' THEN NULL 
        ELSE TRY_CAST(date_registration AS INT) 
    END AS date_registration,
    CASE 
        WHEN date_unregistration = '?' THEN NULL 
        ELSE TRY_CAST(date_unregistration AS INT) 
    END AS date_unregistration,
    -- Calculated: Days enrolled (NULL if either date is missing)
    CASE 
        WHEN date_unregistration = '?' OR date_registration = '?' THEN NULL
        ELSE TRY_CAST(date_unregistration AS INT) - TRY_CAST(date_registration AS INT)
    END AS enrollment_duration_days,
    -- Quality Flag: Track if student completed course (no unregistration = completed)
    CASE WHEN date_unregistration = '?' THEN TRUE ELSE FALSE END AS completed_course
FROM `ftw-week-07`.`01-raw`.student_registration;


-- ============================================================================
-- STUDENT_VLE - Clean version
-- ============================================================================
-- Issues addressed:
--   - 999 cases where same student/site/date appears multiple times
--   - Aggregation strategy: SUM clicks (handles both true duplicates AND multiple sessions)
--   - Flag tracks which records had multiple source rows

CREATE OR REPLACE TABLE `ftw-week-07`.`02-clean`.student_vle (
    id_student INT COMMENT 'Student identifier',
    code_module STRING COMMENT 'Module code',
    code_presentation STRING COMMENT 'Presentation code',
    id_site INT COMMENT 'VLE material identifier',
    date INT COMMENT 'Day offset when accessed',
    sum_click INT COMMENT 'Total clicks (aggregated if multiple records existed)',
    had_multiple_records BOOLEAN COMMENT 'Data quality flag: TRUE if multiple source rows existed for this key'
)
COMMENT 'Clean student VLE interactions with aggregated clicks';

INSERT INTO `ftw-week-07`.`02-clean`.student_vle
SELECT 
    id_student,
    code_module,
    code_presentation,
    id_site,
    -- Transform: Convert date string to INT via TRY_CAST (handles invalid values)
    TRY_CAST(date AS INT) AS date,
    -- Aggregated: Sum clicks across multiple records (handles both true duplicates and multiple sessions)
    SUM(sum_click) AS sum_click,
    -- Quality Flag: Track if multiple source rows existed for this student/site/date combination
    CASE WHEN COUNT(*) > 1 THEN TRUE ELSE FALSE END AS had_multiple_records
FROM `ftw-week-07`.`01-raw`.student_vle
GROUP BY 
    id_student,
    code_module,
    code_presentation,
    id_site,
    date;


-- ============================================================================
-- VLE - Clean version
-- ============================================================================
-- Issues addressed:
--   - 5,243 '?' values in week_from converted to NULL
--   - 5,243 '?' values in week_to converted to NULL
--   - Added data quality flags for missing week boundaries

CREATE OR REPLACE TABLE `ftw-week-07`.`02-clean`.vle (
    id_site INT COMMENT 'Unique VLE material identifier',
    code_module STRING COMMENT 'Module code',
    code_presentation STRING COMMENT 'Presentation code',
    activity_type STRING COMMENT 'Type of VLE activity (20 types)',
    week_from INT COMMENT 'Start week of availability (NULL if unknown)',
    week_to INT COMMENT 'End week of availability (NULL if unknown)',
    has_missing_week_boundaries BOOLEAN COMMENT 'Data quality flag: TRUE if week boundaries unknown'
)
COMMENT 'Clean VLE material definitions with data quality flags';

INSERT INTO `ftw-week-07`.`02-clean`.vle
SELECT 
    id_site,
    code_module,
    code_presentation,
    activity_type,
    -- Transform: Convert string to INT, '?' becomes NULL, invalid values also become NULL via TRY_CAST
    CASE WHEN week_from = '?' THEN NULL ELSE TRY_CAST(week_from AS INT) END AS week_from,
    CASE WHEN week_to = '?' THEN NULL ELSE TRY_CAST(week_to AS INT) END AS week_to,
    -- Quality Flag: Track if source explicitly marked week boundaries as missing with '?'
    CASE WHEN week_from = '?' OR week_to = '?' THEN TRUE ELSE FALSE END AS has_missing_week_boundaries
FROM `ftw-week-07`.`01-raw`.vle;


-- ============================================================================
-- VALIDATION: Clean layer row counts
-- ============================================================================
-- Verify all data was successfully transformed

SELECT 
    'assessments' AS table_name,
    (SELECT COUNT(*) FROM `ftw-week-07`.`02-clean`.assessments) AS clean_count,
    (SELECT COUNT(*) FROM `ftw-week-07`.`01-raw`.assessments) AS raw_count,
    (SELECT COUNT(*) FROM `ftw-week-07`.`02-clean`.assessments WHERE has_missing_due_date = TRUE) AS quality_flag_count

UNION ALL

SELECT 
    'courses' AS table_name,
    (SELECT COUNT(*) FROM `ftw-week-07`.`02-clean`.courses) AS clean_count,
    (SELECT COUNT(*) FROM `ftw-week-07`.`01-raw`.courses) AS raw_count,
    NULL AS quality_flag_count

UNION ALL

SELECT 
    'student_assessment' AS table_name,
    (SELECT COUNT(*) FROM `ftw-week-07`.`02-clean`.student_assessment) AS clean_count,
    (SELECT COUNT(*) FROM `ftw-week-07`.`01-raw`.student_assessment) AS raw_count,
    NULL AS quality_flag_count

UNION ALL

SELECT 
    'student_info' AS table_name,
    (SELECT COUNT(*) FROM `ftw-week-07`.`02-clean`.student_info) AS clean_count,
    (SELECT COUNT(*) FROM `ftw-week-07`.`01-raw`.student_info) AS raw_count,
    (SELECT COUNT(*) FROM `ftw-week-07`.`02-clean`.student_info WHERE has_missing_imd_band = TRUE) AS quality_flag_count

UNION ALL

SELECT 
    'student_registration' AS table_name,
    (SELECT COUNT(*) FROM `ftw-week-07`.`02-clean`.student_registration) AS clean_count,
    (SELECT COUNT(*) FROM `ftw-week-07`.`01-raw`.student_registration) AS raw_count,
    (SELECT COUNT(*) FROM `ftw-week-07`.`02-clean`.student_registration WHERE completed_course = TRUE) AS quality_flag_count

UNION ALL

SELECT 
    'student_vle' AS table_name,
    (SELECT COUNT(*) FROM `ftw-week-07`.`02-clean`.student_vle) AS clean_count,
    (SELECT COUNT(*) FROM `ftw-week-07`.`01-raw`.student_vle) AS raw_count,
    (SELECT COUNT(*) FROM `ftw-week-07`.`02-clean`.student_vle WHERE had_multiple_records = TRUE) AS quality_flag_count

UNION ALL

SELECT 
    'vle' AS table_name,
    (SELECT COUNT(*) FROM `ftw-week-07`.`02-clean`.vle) AS clean_count,
    (SELECT COUNT(*) FROM `ftw-week-07`.`01-raw`.vle) AS raw_count,
    (SELECT COUNT(*) FROM `ftw-week-07`.`02-clean`.vle WHERE has_missing_week_boundaries = TRUE) AS quality_flag_count;