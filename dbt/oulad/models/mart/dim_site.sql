-- ============================================
-- DIM_SITE
-- Grain: one row per VLE site/resource
-- ============================================

SELECT
    ROW_NUMBER() OVER (
        ORDER BY v.id_site
    ) AS site_key,

    v.id_site,
    v.activity_type

FROM {{ source('clean', 'vle') }} AS v