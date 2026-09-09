-- =====================================================================
-- OULAD : BRONZE INGESTION 
-- Target: catalog `ftw-week-07`, schema `01-raw`

-- ---------------------------------------------------------------------
-- 1. RUN CONTEXT
-- ---------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS `ftw-week-07`.`01-raw`;

DECLARE OR REPLACE VARIABLE ingest_batch_id STRING;
SET VARIABLE ingest_batch_id = uuid();


CREATE TABLE IF NOT EXISTS `ftw-week-07`.`01-raw`._ingest_audit (
    ingest_batch_id     STRING,
    audited_at          TIMESTAMP,
    dataset             STRING,
    source_path         STRING,
    source_data_lines   BIGINT,   -- physical lines in file, minus header
    rows_loaded         BIGINT,
    rows_rescued        BIGINT,   -- rows carrying unexpected extra columns
    row_delta           BIGINT,   -- loaded - source; must be 0
    status              STRING
)
COMMENT 'Bronze load reconciliation. One row per dataset per audit batch.';


-- ---------------------------------------------------------------------
-- 2. LOADS
--    Pattern per dataset: declare, copy, reconcile.
--    All three are safe to re-run. Lineage columns are _ prefixed so
--    Silver can drop them with SELECT * EXCEPT (...).
-- ---------------------------------------------------------------------

-- ---------- courses ----------
CREATE TABLE IF NOT EXISTS `ftw-week-07`.`01-raw`.courses (
    code_module                STRING,
    code_presentation          STRING,
    module_presentation_length STRING,
    _rescued_data              STRING,
    _source_file               STRING,
    _source_modified_at        TIMESTAMP,
    _ingested_at               TIMESTAMP
)
COMMENT 'Bronze. As-is load of courses.csv. All source columns STRING.';

COPY INTO `ftw-week-07`.`01-raw`.courses
FROM (
    SELECT
        code_module,
        code_presentation,
        module_presentation_length,
        _rescued_data,
        _metadata.file_path              AS _source_file,
        _metadata.file_modification_time AS _source_modified_at,
        CURRENT_TIMESTAMP()              AS _ingested_at
    FROM '/Volumes/ftw-week-07/00-source/cloudflare-r2/courses.csv'
)
FILEFORMAT = CSV
FORMAT_OPTIONS ('header' = 'true', 'inferSchema' = 'false', 'rescuedDataColumn' = '_rescued_data');

INSERT INTO `ftw-week-07`.`01-raw`._ingest_audit
WITH src AS (
    SELECT COUNT(*) - 1 AS source_data_lines
    FROM read_files('/Volumes/ftw-week-07/00-source/cloudflare-r2/courses.csv', format => 'text')
),
tgt AS (
    SELECT COUNT(*)                                                   AS rows_loaded,
           SUM(CASE WHEN _rescued_data IS NOT NULL THEN 1 ELSE 0 END) AS rows_rescued
    FROM `ftw-week-07`.`01-raw`.courses
)
SELECT ingest_batch_id, CURRENT_TIMESTAMP(), 'courses',
       '/Volumes/ftw-week-07/00-source/cloudflare-r2/courses.csv',
       src.source_data_lines, tgt.rows_loaded, tgt.rows_rescued,
       tgt.rows_loaded - src.source_data_lines,
       CASE WHEN tgt.rows_loaded <> src.source_data_lines THEN 'FAIL'
            WHEN tgt.rows_rescued > 0                     THEN 'WARN'
            ELSE 'PASS' END
FROM src, tgt;


-- ---------- assessments ----------
-- `date` keeps its source name. It is NOT a calendar date: it is an integer
-- day offset from module start. The rename happens in Silver.
CREATE TABLE IF NOT EXISTS `ftw-week-07`.`01-raw`.assessments (
    code_module         STRING,
    code_presentation   STRING,
    id_assessment       STRING,
    assessment_type     STRING,
    `date`              STRING,
    weight              STRING,
    _rescued_data       STRING,
    _source_file        STRING,
    _source_modified_at TIMESTAMP,
    _ingested_at        TIMESTAMP
)
COMMENT 'Bronze. As-is load of assessments.csv. `date` is a day offset, not a date. 11 Exam rows carry ?.';

COPY INTO `ftw-week-07`.`01-raw`.assessments
FROM (
    SELECT
        code_module,
        code_presentation,
        id_assessment,
        assessment_type,
        `date`,
        weight,
        _rescued_data,
        _metadata.file_path              AS _source_file,
        _metadata.file_modification_time AS _source_modified_at,
        CURRENT_TIMESTAMP()              AS _ingested_at
    FROM '/Volumes/ftw-week-07/00-source/cloudflare-r2/assessments.csv'
)
FILEFORMAT = CSV
FORMAT_OPTIONS ('header' = 'true', 'inferSchema' = 'false', 'rescuedDataColumn' = '_rescued_data');

INSERT INTO `ftw-week-07`.`01-raw`._ingest_audit
WITH src AS (
    SELECT COUNT(*) - 1 AS source_data_lines
    FROM read_files('/Volumes/ftw-week-07/00-source/cloudflare-r2/assessments.csv', format => 'text')
),
tgt AS (
    SELECT COUNT(*)                                                   AS rows_loaded,
           SUM(CASE WHEN _rescued_data IS NOT NULL THEN 1 ELSE 0 END) AS rows_rescued
    FROM `ftw-week-07`.`01-raw`.assessments
)
SELECT ingest_batch_id, CURRENT_TIMESTAMP(), 'assessments',
       '/Volumes/ftw-week-07/00-source/cloudflare-r2/assessments.csv',
       src.source_data_lines, tgt.rows_loaded, tgt.rows_rescued,
       tgt.rows_loaded - src.source_data_lines,
       CASE WHEN tgt.rows_loaded <> src.source_data_lines THEN 'FAIL'
            WHEN tgt.rows_rescued > 0                     THEN 'WARN'
            ELSE 'PASS' END
FROM src, tgt;


-- ---------- vle ----------
CREATE TABLE IF NOT EXISTS `ftw-week-07`.`01-raw`.vle (
    id_site             STRING,
    code_module         STRING,
    code_presentation   STRING,
    activity_type       STRING,
    week_from           STRING,
    week_to             STRING,
    _rescued_data       STRING,
    _source_file        STRING,
    _source_modified_at TIMESTAMP,
    _ingested_at        TIMESTAMP
)
COMMENT 'Bronze. As-is load of vle.csv. week_from/week_to carry ? on always-on resources (5,243 rows).';

COPY INTO `ftw-week-07`.`01-raw`.vle
FROM (
    SELECT
        id_site,
        code_module,
        code_presentation,
        activity_type,
        week_from,
        week_to,
        _rescued_data,
        _metadata.file_path              AS _source_file,
        _metadata.file_modification_time AS _source_modified_at,
        CURRENT_TIMESTAMP()              AS _ingested_at
    FROM '/Volumes/ftw-week-07/00-source/cloudflare-r2/vle.csv'
)
FILEFORMAT = CSV
FORMAT_OPTIONS ('header' = 'true', 'inferSchema' = 'false', 'rescuedDataColumn' = '_rescued_data');

INSERT INTO `ftw-week-07`.`01-raw`._ingest_audit
WITH src AS (
    SELECT COUNT(*) - 1 AS source_data_lines
    FROM read_files('/Volumes/ftw-week-07/00-source/cloudflare-r2/vle.csv', format => 'text')
),
tgt AS (
    SELECT COUNT(*)                                                   AS rows_loaded,
           SUM(CASE WHEN _rescued_data IS NOT NULL THEN 1 ELSE 0 END) AS rows_rescued
    FROM `ftw-week-07`.`01-raw`.vle
)
SELECT ingest_batch_id, CURRENT_TIMESTAMP(), 'vle',
       '/Volumes/ftw-week-07/00-source/cloudflare-r2/vle.csv',
       src.source_data_lines, tgt.rows_loaded, tgt.rows_rescued,
       tgt.rows_loaded - src.source_data_lines,
       CASE WHEN tgt.rows_loaded <> src.source_data_lines THEN 'FAIL'
            WHEN tgt.rows_rescued > 0                     THEN 'WARN'
            ELSE 'PASS' END
FROM src, tgt;


-- ---------- student_info ----------
CREATE TABLE IF NOT EXISTS `ftw-week-07`.`01-raw`.student_info (
    code_module          STRING,
    code_presentation    STRING,
    id_student           STRING,
    gender               STRING,
    region               STRING,
    highest_education    STRING,
    imd_band             STRING,
    age_band             STRING,
    num_of_prev_attempts STRING,
    studied_credits      STRING,
    disability           STRING,
    final_result         STRING,
    _rescued_data        STRING,
    _source_file         STRING,
    _source_modified_at  TIMESTAMP,
    _ingested_at         TIMESTAMP
)
COMMENT 'Bronze. As-is load of studentInfo.csv. Grain: one row per student per course presentation.';

COPY INTO `ftw-week-07`.`01-raw`.student_info
FROM (
    SELECT
        code_module,
        code_presentation,
        id_student,
        gender,
        region,
        highest_education,
        imd_band,
        age_band,
        num_of_prev_attempts,
        studied_credits,
        disability,
        final_result,
        _rescued_data,
        _metadata.file_path              AS _source_file,
        _metadata.file_modification_time AS _source_modified_at,
        CURRENT_TIMESTAMP()              AS _ingested_at
    FROM '/Volumes/ftw-week-07/00-source/cloudflare-r2/studentInfo.csv'
)
FILEFORMAT = CSV
FORMAT_OPTIONS ('header' = 'true', 'inferSchema' = 'false', 'rescuedDataColumn' = '_rescued_data');

INSERT INTO `ftw-week-07`.`01-raw`._ingest_audit
WITH src AS (
    SELECT COUNT(*) - 1 AS source_data_lines
    FROM read_files('/Volumes/ftw-week-07/00-source/cloudflare-r2/studentInfo.csv', format => 'text')
),
tgt AS (
    SELECT COUNT(*)                                                   AS rows_loaded,
           SUM(CASE WHEN _rescued_data IS NOT NULL THEN 1 ELSE 0 END) AS rows_rescued
    FROM `ftw-week-07`.`01-raw`.student_info
)
SELECT ingest_batch_id, CURRENT_TIMESTAMP(), 'student_info',
       '/Volumes/ftw-week-07/00-source/cloudflare-r2/studentInfo.csv',
       src.source_data_lines, tgt.rows_loaded, tgt.rows_rescued,
       tgt.rows_loaded - src.source_data_lines,
       CASE WHEN tgt.rows_loaded <> src.source_data_lines THEN 'FAIL'
            WHEN tgt.rows_rescued > 0                     THEN 'WARN'
            ELSE 'PASS' END
FROM src, tgt;


-- ---------- student_registration ----------
CREATE TABLE IF NOT EXISTS `ftw-week-07`.`01-raw`.student_registration (
    code_module         STRING,
    code_presentation   STRING,
    id_student          STRING,
    date_registration   STRING,
    date_unregistration STRING,
    _rescued_data       STRING,
    _source_file        STRING,
    _source_modified_at TIMESTAMP,
    _ingested_at        TIMESTAMP
)
COMMENT 'Bronze. As-is load of studentRegistration.csv. Both date columns are day offsets; ? = absent.';

COPY INTO `ftw-week-07`.`01-raw`.student_registration
FROM (
    SELECT
        code_module,
        code_presentation,
        id_student,
        date_registration,
        date_unregistration,
        _rescued_data,
        _metadata.file_path              AS _source_file,
        _metadata.file_modification_time AS _source_modified_at,
        CURRENT_TIMESTAMP()              AS _ingested_at
    FROM '/Volumes/ftw-week-07/00-source/cloudflare-r2/studentRegistration.csv'
)
FILEFORMAT = CSV
FORMAT_OPTIONS ('header' = 'true', 'inferSchema' = 'false', 'rescuedDataColumn' = '_rescued_data');

INSERT INTO `ftw-week-07`.`01-raw`._ingest_audit
WITH src AS (
    SELECT COUNT(*) - 1 AS source_data_lines
    FROM read_files('/Volumes/ftw-week-07/00-source/cloudflare-r2/studentRegistration.csv', format => 'text')
),
tgt AS (
    SELECT COUNT(*)                                                   AS rows_loaded,
           SUM(CASE WHEN _rescued_data IS NOT NULL THEN 1 ELSE 0 END) AS rows_rescued
    FROM `ftw-week-07`.`01-raw`.student_registration
)
SELECT ingest_batch_id, CURRENT_TIMESTAMP(), 'student_registration',
       '/Volumes/ftw-week-07/00-source/cloudflare-r2/studentRegistration.csv',
       src.source_data_lines, tgt.rows_loaded, tgt.rows_rescued,
       tgt.rows_loaded - src.source_data_lines,
       CASE WHEN tgt.rows_loaded <> src.source_data_lines THEN 'FAIL'
            WHEN tgt.rows_rescued > 0                     THEN 'WARN'
            ELSE 'PASS' END
FROM src, tgt;


-- ---------- student_assessment ----------
CREATE TABLE IF NOT EXISTS `ftw-week-07`.`01-raw`.student_assessment (
    id_assessment       STRING,
    id_student          STRING,
    date_submitted      STRING,
    is_banked           STRING,
    score               STRING,
    _rescued_data       STRING,
    _source_file        STRING,
    _source_modified_at TIMESTAMP,
    _ingested_at        TIMESTAMP
)
COMMENT 'Bronze. As-is load of studentAssessment.csv. No module/presentation column: conform via assessments.';

COPY INTO `ftw-week-07`.`01-raw`.student_assessment
FROM (
    SELECT
        id_assessment,
        id_student,
        date_submitted,
        is_banked,
        score,
        _rescued_data,
        _metadata.file_path              AS _source_file,
        _metadata.file_modification_time AS _source_modified_at,
        CURRENT_TIMESTAMP()              AS _ingested_at
    FROM '/Volumes/ftw-week-07/00-source/cloudflare-r2/studentAssessment.csv'
)
FILEFORMAT = CSV
FORMAT_OPTIONS ('header' = 'true', 'inferSchema' = 'false', 'rescuedDataColumn' = '_rescued_data');

INSERT INTO `ftw-week-07`.`01-raw`._ingest_audit
WITH src AS (
    SELECT COUNT(*) - 1 AS source_data_lines
    FROM read_files('/Volumes/ftw-week-07/00-source/cloudflare-r2/studentAssessment.csv', format => 'text')
),
tgt AS (
    SELECT COUNT(*)                                                   AS rows_loaded,
           SUM(CASE WHEN _rescued_data IS NOT NULL THEN 1 ELSE 0 END) AS rows_rescued
    FROM `ftw-week-07`.`01-raw`.student_assessment
)
SELECT ingest_batch_id, CURRENT_TIMESTAMP(), 'student_assessment',
       '/Volumes/ftw-week-07/00-source/cloudflare-r2/studentAssessment.csv',
       src.source_data_lines, tgt.rows_loaded, tgt.rows_rescued,
       tgt.rows_loaded - src.source_data_lines,
       CASE WHEN tgt.rows_loaded <> src.source_data_lines THEN 'FAIL'
            WHEN tgt.rows_rescued > 0                     THEN 'WARN'
            ELSE 'PASS' END
FROM src, tgt;


-- ---------- student_vle ----------
-- Largest table (~10.6M rows). The only one where the reload cost is real,
-- and the main reason COPY INTO is worth using here.
CREATE TABLE IF NOT EXISTS `ftw-week-07`.`01-raw`.student_vle (
    code_module         STRING,
    code_presentation   STRING,
    id_student          STRING,
    id_site             STRING,
    `date`              STRING,
    sum_click           STRING,
    _rescued_data       STRING,
    _source_file        STRING,
    _source_modified_at TIMESTAMP,
    _ingested_at        TIMESTAMP
)
CLUSTER BY (code_module, code_presentation)
COMMENT 'Bronze. As-is load of studentVle.csv. Grain: one row per student per site per day offset.';

COPY INTO `ftw-week-07`.`01-raw`.student_vle
FROM (
    SELECT
        code_module,
        code_presentation,
        id_student,
        id_site,
        `date`,
        sum_click,
        _rescued_data,
        _metadata.file_path              AS _source_file,
        _metadata.file_modification_time AS _source_modified_at,
        CURRENT_TIMESTAMP()              AS _ingested_at
    FROM '/Volumes/ftw-week-07/00-source/cloudflare-r2/studentVle.csv'
)
FILEFORMAT = CSV
FORMAT_OPTIONS ('header' = 'true', 'inferSchema' = 'false', 'rescuedDataColumn' = '_rescued_data');

INSERT INTO `ftw-week-07`.`01-raw`._ingest_audit
WITH src AS (
    SELECT COUNT(*) - 1 AS source_data_lines
    FROM read_files('/Volumes/ftw-week-07/00-source/cloudflare-r2/studentVle.csv', format => 'text')
),
tgt AS (
    SELECT COUNT(*)                                                   AS rows_loaded,
           SUM(CASE WHEN _rescued_data IS NOT NULL THEN 1 ELSE 0 END) AS rows_rescued
    FROM `ftw-week-07`.`01-raw`.student_vle
)
SELECT ingest_batch_id, CURRENT_TIMESTAMP(), 'student_vle',
       '/Volumes/ftw-week-07/00-source/cloudflare-r2/studentVle.csv',
       src.source_data_lines, tgt.rows_loaded, tgt.rows_rescued,
       tgt.rows_loaded - src.source_data_lines,
       CASE WHEN tgt.rows_loaded <> src.source_data_lines THEN 'FAIL'
            WHEN tgt.rows_rescued > 0                     THEN 'WARN'
            ELSE 'PASS' END
FROM src, tgt;


-- ---------------------------------------------------------------------
-- 3. BRONZE EXIT GATE
--    Silver does not start until this returns 7 rows, zero FAIL.
--    A duplicated load shows up here as row_delta = source_data_lines.
-- ---------------------------------------------------------------------
SELECT
    dataset,
    source_data_lines,
    rows_loaded,
    row_delta,
    rows_rescued,
    status
FROM `ftw-week-07`.`01-raw`._ingest_audit
-- session. qualifier is required: the column and the variable share a name,
-- and an unqualified reference resolves to the column, making the filter a no-op.
WHERE ingest_batch_id = session.ingest_batch_id
ORDER BY CASE status WHEN 'FAIL' THEN 0 WHEN 'WARN' THEN 1 ELSE 2 END, dataset;