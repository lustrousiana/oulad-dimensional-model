-- ============================================
-- DIM_STUDENT_ENROLLMENT
-- Grain: one row per student per course presentation
-- ============================================

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

FROM {{ source('clean', 'student_info') }} AS si

LEFT JOIN {{ source('clean', 'student_registration') }} AS sr
    ON si.id_student = sr.id_student
    AND si.code_module = sr.code_module
    AND si.code_presentation = sr.code_presentation
