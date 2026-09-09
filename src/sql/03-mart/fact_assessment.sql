-- 4. FACT_ASSESSMENT
-- Grain: one row per student enrollment per assessment
-- Source: student_assessment (has no code_module/code_presentation of its own —
-- conformed via assessments, per the bronze comment)

CREATE OR REPLACE TABLE `ftw-week-07`.`03-mart`.fact_assessment AS

SELECT
    ROW_NUMBER() OVER (
        ORDER BY
            se.student_enrollment_key,
            da.assessment_key
    ) AS fact_assessment_key,

    se.student_enrollment_key,   -- FK, nullable: see note on banked assessments below
    da.assessment_key,
    sa.date_submitted,
    sa.is_banked,
    sa.score

FROM `ftw-week-07`.`02-clean`.student_assessment sa
INNER JOIN `ftw-week-07`.`03-mart`.dim_assessment da
    ON sa.id_assessment = da.id_assessment

LEFT JOIN `ftw-week-07`.`03-mart`.dim_student_enrollment se
    ON sa.id_student        = se.id_student
    AND da.code_module       = se.code_module
    AND da.code_presentation = se.code_presentation;



    