-- ============================================
-- DIMENSION TABLES
-- Source: 02-clean
-- ============================================

-- 1. DIM_STUDENT_ENROLLMENT
-- Grain: one row per student per course presentation

CREATE OR REPLACE TABLE `ftw-week-07`.`03-mart`.dim_student_enrollment AS

SELECT
    ROW_NUMBER() OVER (
        ORDER BY
            si.id_student,
            si.code_module,
            si.code_presentation
    ) AS student_enrollment_key,

    si.id_student,
    si.code_module,
    si.code_presentation,
    si.gender,
    si.region,
    si.highest_education,
    si.imd_band,
    si.age_band,
    si.num_of_prev_attempts,
    si.studied_credits,
    si.disability,
    si.final_result,
    sr.date_registration,
    sr.date_unregistration

FROM `ftw-week-07`.`02-clean`.student_info si

LEFT JOIN `ftw-week-07`.`02-clean`.student_registration sr
    ON si.id_student = sr.id_student
    AND si.code_module = sr.code_module
    AND si.code_presentation = sr.code_presentation;


-- 2. DIM_ASSESSMENT
-- Grain: one row per assessment

CREATE OR REPLACE TABLE `ftw-week-07`.`03-mart`.dim_assessment AS

SELECT
    ROW_NUMBER() OVER (
        ORDER BY a.id_assessment
    ) AS assessment_key,

    a.id_assessment,
    a.code_module,
    a.code_presentation,
    a.assessment_type,
    a.due_day_offset,
    a.weight

FROM `ftw-week-07`.`02-clean`.assessments a;


-- 3. DIM_SITE
-- Grain: one row per VLE site/activity

CREATE OR REPLACE TABLE `ftw-week-07`.`03-mart`.dim_site AS

SELECT
    ROW_NUMBER() OVER (
        ORDER BY v.id_site
    ) AS site_key,

    v.id_site,
    v.code_module,
    v.code_presentation,
    v.activity_type,
    v.week_from,
    v.week_to

FROM `ftw-week-07`.`02-clean`.vle v;