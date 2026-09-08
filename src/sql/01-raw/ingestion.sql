-- ASSESSMENTS
CREATE OR REPLACE TABLE `ftw-week-07`.`01-raw`.assessments AS
SELECT
    code_module,
    code_presentation,
    CAST(id_assessment AS INT) AS id_assessment,
    assessment_type,
    date,
    CAST(weight AS DOUBLE) AS weight
FROM read_files('/Volumes/ftw-week-07/00-source/cloudflare-r2/assessments.csv', format => 'csv', header => true);

-- COURSES
CREATE OR REPLACE TABLE `ftw-week-07`.`01-raw`.courses AS
SELECT
    code_module,
    code_presentation,
    CAST(module_presentation_length AS INT) AS module_presentation_length
FROM read_files('/Volumes/ftw-week-07/00-source/cloudflare-r2/courses.csv', format => 'csv', header => true);

-- STUDENT ASSESSMENT
CREATE OR REPLACE TABLE `ftw-week-07`.`01-raw`.student_assessment AS
SELECT
    CAST(id_assessment AS INT) AS id_assessment,
    CAST(id_student AS INT) AS id_student,
    CAST(date_submitted AS INT) AS date_submitted,
    CAST(is_banked AS INT) AS is_banked,
    score
FROM read_files('/Volumes/ftw-week-07/00-source/cloudflare-r2/studentAssessment.csv', format => 'csv', header => true);

-- STUDENT INFO
CREATE OR REPLACE TABLE `ftw-week-07`.`01-raw`.student_info AS
SELECT
    code_module,
    code_presentation,
    CAST(id_student AS INT) AS id_student,
    gender,
    region,
    highest_education,
    imd_band,
    age_band,
    CAST(num_of_prev_attempts AS INT) AS num_of_prev_attempts,
    CAST(studied_credits AS INT) AS studied_credits,
    disability,
    final_result
FROM read_files('/Volumes/ftw-week-07/00-source/cloudflare-r2/studentInfo.csv', format => 'csv', header => true);

-- STUDENT REGISTRATION
CREATE OR REPLACE TABLE `ftw-week-07`.`01-raw`.student_registration AS
SELECT
    code_module,
    code_presentation,
    CAST(id_student AS INT) AS id_student,
    date_registration,
    date_unregistration
FROM read_files('/Volumes/ftw-week-07/00-source/cloudflare-r2/studentRegistration.csv', format => 'csv', header => true);

-- STUDENT VLE
CREATE OR REPLACE TABLE `ftw-week-07`.`01-raw`.student_vle AS
SELECT
    code_module,
    code_presentation,
    CAST(id_student AS INT) AS id_student,
    CAST(id_site AS INT) AS id_site,
    date,
    CAST(sum_click AS INT) AS sum_click
FROM read_files('/Volumes/ftw-week-07/00-source/cloudflare-r2/studentVle.csv', format => 'csv', header => true);

-- VLE
CREATE OR REPLACE TABLE `ftw-week-07`.`01-raw`.vle AS
SELECT
    CAST(id_site AS INT) AS id_site,
    code_module,
    code_presentation,
    activity_type,
    week_from,
    week_to
FROM read_files('/Volumes/ftw-week-07/00-source/cloudflare-r2/vle.csv', format => 'csv', header => true);

-- Verify
SHOW TABLES IN `ftw-week-07`.`01-raw`;