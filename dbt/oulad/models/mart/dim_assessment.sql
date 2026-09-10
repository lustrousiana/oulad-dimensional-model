-- ============================================
-- DIM_ASSESSMENT
-- Grain: one row per assessment
-- ============================================

SELECT
    ROW_NUMBER() OVER (
        ORDER BY a.id_assessment
    ) AS assessment_key,

    a.id_assessment,
    a.code_module,
    a.code_presentation,
    a.assessment_type,
    a.date,
    a.weight

FROM {{ source('clean', 'assessments') }} a
