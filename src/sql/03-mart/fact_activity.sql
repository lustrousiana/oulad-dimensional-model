-- 5. FACT_ACTIVITY
-- Grain: one row per student enrollment per VLE site per activity date
-- Source: student_vle
CREATE OR REPLACE TABLE `ftw-week-07`.`03-mart`.fact_activity AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY
            se.student_enrollment_key,
            ds.site_key,
            sv.date
    ) AS fact_activity_key,
    se.student_enrollment_key,
    ds.site_key,
    sv.date       AS activity_date,
    sv.sum_click  AS total_clicks
FROM `ftw-week-07`.`02-clean`.student_vle sv
LEFT JOIN `ftw-week-07`.`03-mart`.dim_student_enrollment se
    ON sv.id_student        = se.id_student
    AND sv.code_module       = se.code_module
    AND sv.code_presentation = se.code_presentation
LEFT JOIN `ftw-week-07`.`03-mart`.dim_site ds
    ON sv.id_site            = ds.id_site
    AND sv.code_module       = ds.code_module
    AND sv.code_presentation = ds.code_presentation;
