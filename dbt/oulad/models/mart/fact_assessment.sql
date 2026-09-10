SELECT
    ROW_NUMBER() OVER (
        ORDER BY
            se.student_enrollment_key,
            da.assessment_key
    ) AS fact_assessment_key,

    se.student_enrollment_key,
    da.assessment_key,
    sa.date_submitted,
    sa.is_banked,
    sa.score

FROM {{ source('clean', 'student_assessment') }} sa

LEFT JOIN {{ ref('dim_assessment') }} da
    ON sa.id_assessment = da.id_assessment

LEFT JOIN {{ ref('dim_student_enrollment') }} se
    ON sa.id_student = se.id_student
    AND da.code_module = se.code_module
    AND da.code_presentation = se.code_presentation
