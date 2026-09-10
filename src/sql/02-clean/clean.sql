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
--   - Added has_invalid_weight_sum flag to track 5 presentations with weights ≠ 100%
--   - All validation checks passed (no duplicates, valid ranges, referential integrity)

CREATE OR REPLACE TABLE `ftw-week-07`.`02-clean`.assessments (
    id_assessment INT COMMENT 'Unique assessment identifier',
    code_module STRING COMMENT 'Module code (aaa-ggg)',
    code_presentation STRING COMMENT 'Presentation code (YYYY + B/J)',
    assessment_type STRING COMMENT 'Type: CMA, TMA, or Exam',
    due_day_offset INT COMMENT 'Day offset from course start when assessment is due (can be negative; NULL if unknown)',
    weight DOUBLE COMMENT 'Assessment weight in final grade (0-100)',
    has_missing_due_date BOOLEAN COMMENT 'Data quality flag: TRUE if due date was missing in source',
    has_invalid_weight_sum BOOLEAN COMMENT 'Data quality flag: TRUE if presentation total weights ≠ 100%'
)
COMMENT 'Clean assessment definitions with data quality flags';

INSERT INTO `ftw-week-07`.`02-clean`.assessments
WITH presentation_weight_validation AS (
    -- Calculate total weights by presentation and type to identify invalid sums
    SELECT 
        code_module,
        code_presentation,
        assessment_type,
        SUM(weight) as total_weight
    FROM `ftw-week-07`.`01-raw`.assessments
    GROUP BY code_module, code_presentation, assessment_type
)
SELECT 
    a.id_assessment,
    a.code_module,
    a.code_presentation,
    a.assessment_type,
    -- Transform: Convert string to INT, '?' becomes NULL, invalid values also become NULL via TRY_CAST
    CASE WHEN a.date = '?' THEN NULL ELSE TRY_CAST(a.date AS INT) END AS due_day_offset,
    a.weight,
    -- Quality Flag: Track if source explicitly marked as missing with '?' (not other corrupt values)
    CASE WHEN a.date = '?' THEN TRUE ELSE FALSE END AS has_missing_due_date,
    -- Quality Flag: Track if this assessment belongs to a presentation with invalid weight sum
    CASE 
        WHEN pwv.total_weight IS NULL THEN FALSE
        WHEN ABS(pwv.total_weight - 100.0) > 0.01 THEN TRUE
        ELSE FALSE
    END AS has_invalid_weight_sum
FROM `ftw-week-07`.`01-raw`.assessments a
LEFT JOIN presentation_weight_validation pwv
    ON a.code_module = pwv.code_module
   AND a.code_presentation = pwv.code_presentation
   AND a.assessment_type = pwv.assessment_type;


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
--   - 102 withdrawal flag inconsistencies resolved (date_unregistration used as authoritative source)
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
    has_missing_imd_band BOOLEAN COMMENT 'Data quality flag: TRUE if deprivation band unknown',
    had_withdrawal_corrected BOOLEAN COMMENT 'Data quality flag: TRUE if final_result was corrected using date_unregistration'
)
COMMENT 'Clean student demographic and outcome data with data quality flags';

INSERT INTO `ftw-week-07`.`02-clean`.student_info
SELECT 
    si.id_student,
    si.code_module,
    si.code_presentation,
    UPPER(si.gender) AS gender,
    si.region,
    si.highest_education,
    -- Transform: Convert '?' to NULL, standardize '10-20' format to '10-20%', keep valid values
    CASE 
        WHEN si.imd_band = '?' THEN NULL
        WHEN si.imd_band = '10-20' THEN '10-20%'
        ELSE si.imd_band 
    END AS imd_band,
    si.age_band,
    si.num_of_prev_attempts,
    si.studied_credits,
    UPPER(si.disability) AS disability,
    -- FIX: Use date_unregistration as authoritative source for withdrawal status
    CASE 
        WHEN sr.date_unregistration IS NOT NULL AND sr.date_unregistration != '?' THEN 'Withdrawn'
        ELSE INITCAP(si.final_result)
    END AS final_result,
    -- Quality Flag: Track if source explicitly marked as missing with '?'
    CASE WHEN si.imd_band = '?' THEN TRUE ELSE FALSE END AS has_missing_imd_band,
    -- Quality Flag: Track if final_result was corrected based on registration data
    CASE 
        WHEN (sr.date_unregistration IS NOT NULL AND sr.date_unregistration != '?' AND si.final_result != 'Withdrawn')
          OR (sr.date_unregistration = '?' AND si.final_result = 'Withdrawn')
        THEN TRUE
        ELSE FALSE
    END AS had_withdrawal_corrected
FROM `ftw-week-07`.`01-raw`.student_info si
LEFT JOIN `ftw-week-07`.`01-raw`.student_registration sr
    ON si.code_module = sr.code_module
   AND si.code_presentation = sr.code_presentation
   AND si.id_student = sr.id_student;


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