-- ============================================
-- DIM_SITE
-- Grain: one row per VLE site/resource
-- ============================================

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

FROM {{ source('clean', 'vle') }} v
