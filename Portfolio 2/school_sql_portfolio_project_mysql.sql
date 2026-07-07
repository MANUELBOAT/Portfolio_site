/* ============================================================
   SCHOOL STUDENT RECORDS ANALYSIS — SQL PORTFOLIO PROJECT
   Dialect: MySQL 8.0+

   What this project is about:
   Schools deal with the same kind of messy data as hospitals or
   stores — enrollment forms, grade sheets, and fee records that
   were entered by different people, at different times, in
   different formats.

   This project walks through:
     1. Setting up a raw (messy) student records table
     2. Filling it with realistic, imperfect sample data
     3. Cleaning that data step by step, explaining each fix
     4. Running real school-management style analysis on it
   ============================================================ */


/* ============================================================
   1. RAW TABLE — THE "BEFORE" VERSION
   Think of this as an export pulled from an old school database,
   combined with a teacher's handwritten gradebook someone typed up.
   ============================================================ */

DROP TABLE IF EXISTS raw_student_records;

CREATE TABLE raw_student_records (
    record_id           VARCHAR(20),
    student_name        VARCHAR(100),
    grade_level         VARCHAR(10),
    subject             VARCHAR(50),
    teacher_name        VARCHAR(100),
    enrollment_date     VARCHAR(20),   -- inconsistent formats, on purpose
    exam_score          VARCHAR(10),   -- stored as text, sometimes with stray characters
    attendance_pct      VARCHAR(10),   -- stored as text, sometimes with a % sign
    fees_paid           VARCHAR(20),   -- stored as text, sometimes with $ signs
    status              VARCHAR(20)
);


/* ============================================================
   2. SAMPLE DATA — WARTS AND ALL
   A few things to notice as you read through this:
   - Some names have extra spaces or odd casing
   - Dates show up in at least 3 different formats
   - A couple of records are exact duplicates (entered twice)
   - One student is missing an exam score (transferred mid-term?)
   - One attendance value got corrupted somewhere along the way
   ============================================================ */

INSERT INTO raw_student_records VALUES
('STU3001', 'Nana Yeboah',     'Grade 9',  'Mathematics', 'Mr. Emmanuel Owusu',  '2024-01-10', '78',  '92%', '$150.00', 'Active'),
('STU3002', ' abena kufuor ',  'grade 9',  'english',     'mrs. joyce appiah',   '01/11/2024', '85',  '88%', '150.00',  'active'),
('STU3003', 'Kwame Tetteh',    'Grade 10', 'Science',     'Dr. Peter Sarpong',   '2024-01-12', NULL,  '95%', '$200.00', 'Active'),   -- missing exam score, transferred mid-term
('STU3004', 'Adjoa Frimpong',  'Grade 9',  'Mathematics', 'Mr. Emmanuel Owusu',  '2024-01-13', '91',  '97%', '150.00',  'Active'),
('STU3005', 'Adjoa Frimpong',  'Grade 9',  'Mathematics', 'Mr. Emmanuel Owusu',  '2024-01-13', '91',  '97%', '150.00',  'Active'),  -- exact duplicate entry
('STU3006', 'Yaw Antwi',       'Grade 11', 'Physics',     'Dr. Peter Sarpong',   '2024/01/14', '67',  '80%', '200.00',  'Active'),
('STU3007', 'Esi Amoah',       'grade 10', 'science',     'dr. peter sarpong',   '14-01-2024', '88',  '90%', '$200.00', 'active'),
('STU3008', 'Kojo Mensah',     'Grade 11', 'Physics',     'Dr. Peter Sarpong',   '2024-01-15', '73',  'abc', '200.00',  'Active'),  -- corrupted attendance value
('STU3009', 'Afia Boadu',      'Grade 10', 'English',     'Mrs. Joyce Appiah',   '2024-01-16', '95',  '99%', NULL,      'Active'),  -- missing fee record
('STU3010', 'Kwabena Osei',    'Grade 9',  'English',     'Mrs. Joyce Appiah',   '2024-01-17', '58',  '70%', '150.00',  'Active'),
('STU3011', 'Abena Nyame',     'Grade 11', 'Mathematics', 'Mr. Emmanuel Owusu',  '2024-01-18', '82',  '85%', '150.00',  'Inactive'), -- withdrew from school
('STU3012', 'Yaa Asantewaa',   'Grade 10', 'Science',     'Dr. Peter Sarpong',   '2024-01-19', '99',  '100%','200.00',  'Active');


/* ============================================================
   3. CLEANING THE DATA
   Every fix below solves one specific problem we spotted above.
   The comments explain the "why", not just the "what" — that's
   the part that actually matters when someone reviews your work.
   ============================================================ */

DROP TABLE IF EXISTS clean_student_records;

CREATE TABLE clean_student_records AS
WITH standardized AS (
    SELECT
        record_id,

        -- Names come in with random spacing and casing (" abena kufuor "
        -- vs "Nana Yeboah"). We trim and force Title Case so every name
        -- looks like it came from the same system.
        TRIM(student_name)                                  AS student_name_raw,

        -- Grade levels had mixed casing ("grade 9" vs "Grade 9") which
        -- would otherwise split one grade into two separate groups
        -- in any report that groups by grade level.
        CONCAT(
            UCASE(LEFT(TRIM(grade_level), 1)),
            LCASE(SUBSTRING(TRIM(grade_level), 2))
        )                                                    AS grade_level,

        TRIM(subject)                                        AS subject_raw,

        -- Teacher names have the same casing issue, plus titles
        -- ("Mr.", "Mrs.", "Dr.") show up in different capitalizations.
        TRIM(teacher_name)                                   AS teacher_name_raw,

        -- Enrollment dates arrive in different formats depending on
        -- which system or person entered them. We try each known
        -- format until one matches.
        COALESCE(
            STR_TO_DATE(NULLIF(enrollment_date, ''), '%Y-%m-%d'),
            STR_TO_DATE(NULLIF(enrollment_date, ''), '%m/%d/%Y'),
            STR_TO_DATE(NULLIF(enrollment_date, ''), '%Y/%m/%d'),
            STR_TO_DATE(NULLIF(enrollment_date, ''), '%d-%m-%Y')
        )                                                    AS enrollment_date,

        -- Exam scores should just be whole numbers 0-100. Anything
        -- that isn't gets treated as "not recorded yet" rather than
        -- silently becoming 0, which would wreck any average we run.
        CASE
            WHEN exam_score REGEXP '^[0-9]+$'
                 AND CAST(exam_score AS UNSIGNED) BETWEEN 0 AND 100
                THEN CAST(exam_score AS UNSIGNED)
            ELSE NULL
        END                                                  AS exam_score,

        -- Attendance sometimes has a trailing '%' sign, and one row
        -- ('abc') is just corrupted. We strip the '%' and validate
        -- what's left is a real number before trusting it.
        CASE
            WHEN REPLACE(attendance_pct, '%', '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
                THEN CAST(REPLACE(attendance_pct, '%', '') AS DECIMAL(5,2))
            ELSE NULL
        END                                                  AS attendance_pct,

        -- Fees follow the same pattern as treatment costs in the
        -- hospital version: strip out $ signs, validate, and turn
        -- anything unrecoverable into a clear NULL instead of a 0
        -- that could get mistaken for "paid nothing."
        CASE
            WHEN REGEXP_REPLACE(fees_paid, '[^0-9.]', '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
                THEN CAST(REGEXP_REPLACE(fees_paid, '[^0-9.]', '') AS DECIMAL(10,2))
            ELSE NULL
        END                                                  AS fees_paid,

        UPPER(TRIM(status))                                  AS status_raw,

        -- Some students got entered twice on the same day with the
        -- exact same details (common when both a teacher and the
        -- school office record enrollment separately). We keep only
        -- the first occurrence of each unique student/subject combo.
        ROW_NUMBER() OVER (
            PARTITION BY
                LOWER(TRIM(student_name)),
                TRIM(subject),
                enrollment_date
            ORDER BY record_id
        ) AS dup_rank

    FROM raw_student_records
    WHERE student_name IS NOT NULL
      AND enrollment_date IS NOT NULL   -- a record needs an enrollment date to mean anything
)

SELECT
    record_id,

    -- Manual title-case, since MySQL has no built-in INITCAP()
    CONCAT(
        UCASE(LEFT(student_name_raw, 1)),
        LCASE(SUBSTRING(student_name_raw, 2))
    )                                                    AS student_name,

    grade_level,

    CONCAT(
        UCASE(LEFT(subject_raw, 1)),
        LCASE(SUBSTRING(subject_raw, 2))
    )                                                    AS subject,

    CONCAT(
        UCASE(LEFT(teacher_name_raw, 1)),
        LCASE(SUBSTRING(teacher_name_raw, 2))
    )                                                    AS teacher_name,

    enrollment_date,
    exam_score,
    attendance_pct,
    fees_paid,

    CASE
        WHEN status_raw = 'INACTIVE' THEN 'Inactive'
        ELSE 'Active'
    END                                                  AS status

FROM standardized
WHERE dup_rank = 1   -- drop the duplicate enrollment entries
;


-- Quick gut-check: how many rows did we start with vs. end up with?
SELECT
    (SELECT COUNT(*) FROM raw_student_records)   AS raw_row_count,
    (SELECT COUNT(*) FROM clean_student_records) AS clean_row_count;


/* ============================================================
   4. ANALYSIS QUERIES
   These are the kinds of questions a school administrator,
   head teacher, or academic office would actually ask.
   ============================================================ */

-- 4.1 Average exam score by subject — quick pulse check on which
--     subjects students are finding harder or easier overall.
SELECT
    subject,
    COUNT(*)                        AS students_recorded,
    ROUND(AVG(exam_score), 1)       AS avg_exam_score
FROM clean_student_records
WHERE exam_score IS NOT NULL   -- exclude students without a recorded score yet
GROUP BY subject
ORDER BY avg_exam_score DESC;


-- 4.2 Top 5 performing students overall — handy for honor roll
--     or scholarship shortlists.
SELECT
    student_name,
    grade_level,
    subject,
    exam_score
FROM clean_student_records
WHERE exam_score IS NOT NULL
ORDER BY exam_score DESC
LIMIT 5;


-- 4.3 Average attendance by grade level — helps flag which grade
--     might need a closer look at engagement or transport issues.
SELECT
    grade_level,
    ROUND(AVG(attendance_pct), 1) AS avg_attendance_pct
FROM clean_student_records
WHERE attendance_pct IS NOT NULL
GROUP BY grade_level
ORDER BY avg_attendance_pct DESC;


-- 4.4 Teacher workload — how many students each teacher is
--     currently responsible for, and what subject(s) they cover.
SELECT
    teacher_name,
    subject,
    COUNT(*) AS students_taught
FROM clean_student_records
WHERE status = 'Active'
GROUP BY teacher_name, subject
ORDER BY students_taught DESC;


-- 4.5 Fees collected so far, and how many students still owe or
--     have no fee record on file — useful for the finance office.
SELECT
    COUNT(*)                                        AS total_active_students,
    SUM(fees_paid)                                   AS total_fees_collected,
    COUNT(*) - COUNT(fees_paid)                      AS students_missing_fee_record
FROM clean_student_records
WHERE status = 'Active';


-- 4.6 Students below a passing threshold (say, 50) — an early
--     warning list for students who might need extra support.
SELECT
    student_name,
    grade_level,
    subject,
    exam_score
FROM clean_student_records
WHERE exam_score IS NOT NULL
  AND exam_score < 50
ORDER BY exam_score ASC;


-- 4.7 Monthly enrollment trend — useful for planning ahead of
--     new terms or spotting unusual drop-off periods.
SELECT
    DATE_FORMAT(enrollment_date, '%Y-%m-01') AS month,
    COUNT(*) AS total_enrollments
FROM clean_student_records
GROUP BY 1
ORDER BY 1;

/* ============================================================
   END OF PROJECT
   Portfolio notes:
   - Requires MySQL 8.0+ (uses CTEs and window functions).
   - To make this a live project, swap raw_student_records with
     a real school data export via LOAD DATA INFILE.
   - Consider pairing this with a one-paragraph write-up on how
     a school office would actually use each query day-to-day —
     that context is what makes a portfolio piece memorable.
   ============================================================ */
