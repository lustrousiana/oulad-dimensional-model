CREATE OR REPLACE TABLE `ftw-week-07`.`04-analytics`.tbl_engagement_performance AS

WITH engagement AS (
    SELECT
        student_enrollment_key,
        SUM(total_clicks)                                                       AS total_clicks,
        COUNT(DISTINCT activity_date)                                           AS active_days,
        ROUND(SUM(total_clicks) / NULLIF(COUNT(DISTINCT activity_date), 0), 2)  AS avg_clicks_per_active_day
    FROM `ftw-week-07`.`03-mart`.fact_activity
    GROUP BY student_enrollment_key
),
performance AS (
    SELECT
        fa.student_enrollment_key,
        COUNT(*)                                                        AS assessments_submitted,
        ROUND(AVG(fa.score), 2)                                         AS avg_score_simple,
        ROUND(SUM(fa.score * da.weight) / NULLIF(SUM(da.weight), 0), 2) AS avg_score_weighted
    FROM `ftw-week-07`.`03-mart`.fact_assessment fa
    INNER JOIN `ftw-week-07`.`03-mart`.dim_assessment da
        ON fa.assessment_key = da.assessment_key
    WHERE fa.score IS NOT NULL
    GROUP BY fa.student_enrollment_key
)

SELECT
    se.student_enrollment_key,
    se.id_student,
    se.code_module,
    se.code_presentation,
    se.final_result,
    COALESCE(e.total_clicks, 0)          AS total_clicks,
    COALESCE(e.active_days, 0)           AS active_days,
    e.avg_clicks_per_active_day,
    COALESCE(p.assessments_submitted, 0) AS assessments_submitted,
    p.avg_score_simple,
    p.avg_score_weighted

FROM `ftw-week-07`.`03-mart`.dim_student_enrollment se
LEFT JOIN engagement e  ON se.student_enrollment_key = e.student_enrollment_key
LEFT JOIN performance p ON se.student_enrollment_key = p.student_enrollment_key;