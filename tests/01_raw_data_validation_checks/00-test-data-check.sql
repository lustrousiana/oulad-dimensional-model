SELECT code_module, code_presentation, id_student, id_site, date, COUNT(*) AS row_count
FROM student_vle
GROUP BY code_module, code_presentation, id_student, id_site, date
HAVING COUNT(*) > 1;