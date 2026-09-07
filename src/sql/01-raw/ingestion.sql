-- ASSESSMENTS
CREATE OR REPLACE TABLE `ftw-week-07`.`01-raw`.assessments (
    code_module STRING,
    code_presentation STRING,
    id_assessment INT,
    assessment_type STRING,
    date STRING,
    weight DOUBLE
);

INSERT INTO `ftw-week-07`.`01-raw`.assessments
SELECT code_module, code_presentation, id_assessment, assessment_type, date, weight
FROM read_files('/Volumes/ftw-week-07/00-source/cloudflare-r2/assessments.csv', format => 'csv', header => true);


-- COURSES
CREATE OR REPLACE TABLE `ftw-week-07`.`01-raw`.courses (
    code_module STRING,
    code_presentation STRING,
    module_presentation_length INT
);

INSERT INTO `ftw-week-07`.`01-raw`.courses
SELECT code_module, code_presentation, module_presentation_length
FROM read_files('/Volumes/ftw-week-07/00-source/cloudflare-r2/courses.csv', format => 'csv', header => true);


-- STUDENT ASSESSMENT
CREATE OR REPLACE TABLE `ftw-week-07`.`01-raw`.student_assessment (
    id_assessment INT,
    id_student INT,
    date_submitted INT,
    is_banked INT,
    score STRING
);

INSERT INTO `ftw-week-07`.`01-raw`.student_assessment
SELECT id_assessment, id_student, date_submitted, is_banked, score
FROM read_files('/Volumes/ftw-week-07/00-source/cloudflare-r2/studentAssessment.csv', format => 'csv', header => true);


-- STUDENT INFO
CREATE OR REPLACE TABLE `ftw-week-07`.`01-raw`.student_info (
    code_module STRING,
    code_presentation STRING,
    id_student INT,
    gender STRING,
    region STRING,
    highest_education STRING,
    imd_band STRING,
    age_band STRING,
    num_of_prev_attempts INT,
    studied_credits INT,
    disability STRING,
    final_result STRING
);

INSERT INTO `ftw-week-07`.`01-raw`.student_info
SELECT code_module, code_presentation, id_student, gender, region, highest_education, imd_band, age_band, num_of_prev_attempts, studied_credits, disability, final_result
FROM read_files('/Volumes/ftw-week-07/00-source/cloudflare-r2/studentInfo.csv', format => 'csv', header => true);


-- STUDENT REGISTRATION
CREATE OR REPLACE TABLE `ftw-week-07`.`01-raw`.student_registration (
    code_module STRING,
    code_presentation STRING,
    id_student INT,
    date_registration STRING,
    date_unregistration STRING
);

INSERT INTO `ftw-week-07`.`01-raw`.student_registration
SELECT code_module, code_presentation, id_student, date_registration, date_unregistration
FROM read_files('/Volumes/ftw-week-07/00-source/cloudflare-r2/studentRegistration.csv', format => 'csv', header => true);
-- STUDENT VLE
CREATE OR REPLACE TABLE `ftw-week-07`.`01-raw`.student_vle (
    code_module STRING,
    code_presentation STRING,
    id_student INT,
    id_site INT,
    date STRING,
    sum_click INT
);

INSERT INTO `ftw-week-07`.`01-raw`.student_vle
SELECT
    code_module,
    code_presentation,
    id_student,
    id_site,
    date,
    sum_click
FROM read_files(
    '/Volumes/ftw-week-07/00-source/cloudflare-r2/studentVle.csv',
    format => 'csv',
    header => true
);
-- VLE
CREATE OR REPLACE TABLE `ftw-week-07`.`01-raw`.vle (
    id_site INT,
    code_module STRING,
    code_presentation STRING,
    activity_type STRING,
    week_from STRING,
    week_to STRING
);

INSERT INTO `ftw-week-07`.`01-raw`.vle
SELECT
    id_site,
    code_module,
    code_presentation,
    activity_type,
    week_from,
    week_to
FROM read_files(
    '/Volumes/ftw-week-07/00-source/cloudflare-r2/vle.csv',
    format => 'csv',
    header => true
);



SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT id_assessment) AS unique_assessment_ids,
    COUNT(*) - COUNT(DISTINCT id_assessment) AS possible_duplicate_ids
FROM `ftw-week-07`.`01-raw`.assessments;