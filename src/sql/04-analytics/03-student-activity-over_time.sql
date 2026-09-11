CREATE OR REPLACE TABLE `ftw-week-07`.`04-analytics`.tbl_activity_over_time AS

SELECT
    dse.code_module,
    dse.code_presentation,
    ds.activity_type,

    CASE
        WHEN fa.activity_date < 0 THEN 0
        ELSE FLOOR(fa.activity_date / 7) + 1
    END AS course_week_number,

    CASE
        WHEN fa.activity_date < 0 THEN 'Before course'
        ELSE CONCAT(
            'Week ',
            CAST(FLOOR(fa.activity_date / 7) + 1 AS INT)
        )
    END AS course_week,

    SUM(fa.total_clicks) AS total_clicks

FROM `ftw-week-07`.`03-mart`.fact_activity AS fa

JOIN `ftw-week-07`.`03-mart`.dim_student_enrollment AS dse
    ON fa.student_enrollment_key = dse.student_enrollment_key

JOIN `ftw-week-07`.`03-mart`.dim_site AS ds
    ON fa.site_key = ds.site_key

GROUP BY
    dse.code_module,
    dse.code_presentation,
    ds.activity_type,

    CASE
        WHEN fa.activity_date < 0 THEN 0
        ELSE FLOOR(fa.activity_date / 7) + 1
    END,

    CASE
        WHEN fa.activity_date < 0 THEN 'Before course'
        ELSE CONCAT(
            'Week ',
            CAST(FLOOR(fa.activity_date / 7) + 1 AS INT)
        )
    END

ORDER BY
    dse.code_module,
    dse.code_presentation,
    course_week_number,
    ds.activity_type;