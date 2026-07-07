/* ============================================================
   HOSPITAL PATIENT RECORDS ANALYSIS — SQL PORTFOLIO PROJECT


   What this project is about:
   Hospitals collect a LOT of messy data — patient intake forms,
   billing exports, doctor notes — all coming from different
   systems that don't agree on date formats, spelling, or casing.

   This project walks through:
     1. Setting up a raw (messy) hospital records table
     2. Filling it with realistic, imperfect sample data
     3. Cleaning that data step by step, explaining each fix
     4. Running real hospital-management style analysis on it
   ============================================================ */




DROP TABLE IF EXISTS raw_patient_records;

CREATE TABLE raw_patient_records (
    record_id           VARCHAR(20),
    patient_name        VARCHAR(100),
    gender              VARCHAR(10),
    date_of_birth       VARCHAR(20),   -- inconsistent formats, on purpose
    department          VARCHAR(50),
    doctor_name         VARCHAR(100),
    admission_date      VARCHAR(20),   -- inconsistent formats, on purpose
    discharge_date      VARCHAR(20),   -- inconsistent formats, on purpose
    diagnosis           VARCHAR(100),
    treatment_cost      VARCHAR(20),   -- stored as text, sometimes with $ signs
    insurance_provider  VARCHAR(50),
    status              VARCHAR(20)
);




INSERT INTO raw_patient_records VALUES
('REC2001', 'Grace Owusu',     'F', '1990-04-12', 'Cardiology',   'Dr. Kwame Mensah',  '2024-02-01', '2024-02-05', 'Hypertension',      '$1200.00', 'NHIS',       'Discharged'),
('REC2002', ' kofi asante ',  'M', '05/14/1985', 'Orthopedics',  'dr. ama boateng',    '02/03/2024', '02/10/2024', 'fracture',          '2500',     'Private',    'discharged'),
('REC2003', 'Efua Mensah',     'F', '1978-11-30', 'Pediatrics',   'Dr. John Osei',     '2024-02-04', NULL,         'Asthma',            '$800.00',  'NHIS',       'Admitted'),   -- still admitted, no discharge yet
('REC2004', 'Kwabena Boateng', 'M', '1965-06-22', 'Cardiology',   'Dr. Kwame Mensah',  '2024-02-06', '2024-02-09', 'Hypertension',      '1200.00',  'NHIS',       'Discharged'),
('REC2005', 'Kwabena Boateng', 'M', '1965-06-22', 'Cardiology',   'Dr. Kwame Mensah',  '2024-02-06', '2024-02-09', 'Hypertension',      '1200.00',  'NHIS',       'Discharged'),  -- exact duplicate entry
('REC2006', 'Ama Serwaa',      'F', '1999-01-15', 'Gynecology',   'Dr. Linda Addo',    '2024/02/07', '2024/02/09', 'Prenatal Checkup',  '400.00',   'Private',    'Discharged'),
('REC2007', 'Yaw Darko',       'M', '1988-09-09', 'Orthopedics',  'Dr. Ama Boateng',   '07-02-2024', '09-02-2024', 'fracture',          '$2500.00', 'Private',    'discharged'),
('REC2008', 'Abena Nyarko',    'F', '2001-03-03', 'Pediatrics',   'Dr. John Osei',     '2024-02-08', '2024-02-10', 'Malaria',           '350.00',   'NHIS',       'Discharged'),
('REC2009', 'Kojo Adjei',      'M', NULL,          'Neurology',    'Dr. Sarah Nti',     '2024-02-09', '2024-02-15', 'Migraine',          '600.00',   NULL,        'Discharged'),  -- missing DOB and insurance
('REC2010', 'Adwoa Fosu',      'F', '1995-07-19', 'Neurology',    'Dr. Sarah Nti',     '2024-02-10', '2024-02-11', 'Migraine',          'xyz',      'Private',    'Discharged'),  -- corrupted cost
('REC2011', 'Kwesi Amankwah',  'M', '1972-12-05', 'Cardiology',   'Dr. Kwame Mensah',  '2024-02-11', '2024-02-14', 'Heart Arrhythmia',  '3200.00',  'NHIS',       'Discharged'),
('REC2012', 'Akosua Baah',     'F', '1983-05-27', 'Gynecology',   'Dr. Linda Addo',    '2024-02-12', '2024-02-13', 'Prenatal Checkup',  '400.00',   'Private',    'Discharged');


/* ============================================================
   3. CLEANING THE DATA
   Every fix below solves one specific problem we spotted above.
   The comments explain the "why", not just the "what" — that's
   the part that actually matters when someone reviews your work.
   ============================================================ */

DROP TABLE IF EXISTS clean_patient_records;

CREATE TABLE clean_patient_records AS
WITH standardized AS (
    SELECT
        record_id,

        -- Names come in with random spacing and casing (" kofi asante " vs
        -- "Grace Owusu"). We trim the whitespace and force consistent
        -- Title Case so every name looks like it came from the same system.
        TRIM(patient_name)                                  AS patient_name_raw,

        -- Gender codes are already clean here, but we standardize case
        -- anyway in case future imports use lowercase 'f'/'m'.
        UPPER(TRIM(gender))                                 AS gender,

        -- Birthdates and hospital dates arrive in different formats
        -- depending on which system exported them. We try each known
        -- format until one matches — this is the same trick used for
        -- the admission and discharge dates below.
        COALESCE(
            STR_TO_DATE(NULLIF(date_of_birth, ''), '%Y-%m-%d'),
            STR_TO_DATE(NULLIF(date_of_birth, ''), '%m/%d/%Y'),
            STR_TO_DATE(NULLIF(date_of_birth, ''), '%Y/%m/%d'),
            STR_TO_DATE(NULLIF(date_of_birth, ''), '%d-%m-%Y')
        )                                                    AS date_of_birth,

        TRIM(department)                                    AS department,

        -- Doctor names have the same casing issue as patient names,
        -- plus "Dr." shows up with different capitalization.
        TRIM(doctor_name)                                   AS doctor_name_raw,

        COALESCE(
            STR_TO_DATE(NULLIF(admission_date, ''), '%Y-%m-%d'),
            STR_TO_DATE(NULLIF(admission_date, ''), '%m/%d/%Y'),
            STR_TO_DATE(NULLIF(admission_date, ''), '%Y/%m/%d'),
            STR_TO_DATE(NULLIF(admission_date, ''), '%d-%m-%Y')
        )                                                    AS admission_date,

        -- Discharge date can legitimately be missing (patient still
        -- admitted), so we don't drop those rows — we just leave it NULL
        -- and flag it as "Admitted" in the status field further down.
        COALESCE(
            STR_TO_DATE(NULLIF(discharge_date, ''), '%Y-%m-%d'),
            STR_TO_DATE(NULLIF(discharge_date, ''), '%m/%d/%Y'),
            STR_TO_DATE(NULLIF(discharge_date, ''), '%Y/%m/%d'),
            STR_TO_DATE(NULLIF(discharge_date, ''), '%d-%m-%Y')
        )                                                    AS discharge_date,

        -- Diagnoses had mixed casing ("fracture" vs "Fracture") which
        -- would otherwise split one diagnosis into two rows in a report.
        TRIM(diagnosis)                                     AS diagnosis_raw,

        -- Strip out $ signs and any stray characters, keep only digits
        -- and the decimal point, then validate it's a real number.
        -- Anything that doesn't survive this (like 'xyz') becomes NULL
        -- instead of silently becoming 0 or crashing the whole import.
        CASE
            WHEN REGEXP_REPLACE(treatment_cost, '[^0-9.]', '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
                THEN CAST(REGEXP_REPLACE(treatment_cost, '[^0-9.]', '') AS DECIMAL(10,2))
            ELSE NULL
        END                                                  AS treatment_cost,

        -- Missing insurance provider just means "we don't know yet" —
        -- we label it explicitly instead of leaving a blank that's easy
        -- to misread later as "no insurance".
        COALESCE(NULLIF(TRIM(insurance_provider), ''), 'Unknown') AS insurance_provider,

        UPPER(TRIM(status))                                 AS status_raw,

        -- Two rows can look identical if the same admission got entered
        -- twice by accident (common with manual intake forms). We keep
        -- only the first occurrence of each unique patient/admission.
        ROW_NUMBER() OVER (
            PARTITION BY
                LOWER(TRIM(patient_name)),
                admission_date,
                discharge_date,
                department
            ORDER BY record_id
        ) AS dup_rank

    FROM raw_patient_records
    WHERE patient_name IS NOT NULL
      AND admission_date IS NOT NULL   -- an admission record needs an admission date to mean anything
)

SELECT
    record_id,

    -- Manual title-case, since MySQL has no built-in INITCAP()
    CONCAT(
        UCASE(LEFT(patient_name_raw, 1)),
        LCASE(SUBSTRING(patient_name_raw, 2))
    )                                                    AS patient_name,

    gender,
    date_of_birth,
    department,

    CONCAT(
        UCASE(LEFT(doctor_name_raw, 1)),
        LCASE(SUBSTRING(doctor_name_raw, 2))
    )                                                    AS doctor_name,

    admission_date,
    discharge_date,

    CONCAT(
        UCASE(LEFT(diagnosis_raw, 1)),
        LCASE(SUBSTRING(diagnosis_raw, 2))
    )                                                    AS diagnosis,

    treatment_cost,
    insurance_provider,

    -- If there's no discharge date, the patient is still admitted —
    -- regardless of what the original status field said.
    CASE
        WHEN discharge_date IS NULL THEN 'Admitted'
        ELSE 'Discharged'
    END                                                  AS status,

    -- Length of stay is one of the most requested hospital metrics,
    -- so we calculate it once here instead of redoing it in every query.
    DATEDIFF(discharge_date, admission_date)            AS length_of_stay_days

FROM standardized
WHERE dup_rank = 1                -- drop the duplicate intake entries
  AND treatment_cost IS NOT NULL  -- drop rows where cost couldn't be recovered
  AND admission_date IS NOT NULL;


-- Quick gut-check: how many rows did we start with vs. end up with?
SELECT
    (SELECT COUNT(*) FROM raw_patient_records)   AS raw_row_count,
    (SELECT COUNT(*) FROM clean_patient_records) AS clean_row_count;


/* ============================================================
   4. ANALYSIS QUERIES
   These are the kinds of questions a hospital administrator
   or ops team would actually ask.
   ============================================================ */

-- 4.1 How many patients came through each department, and what did
--     it cost in total? Good starting point for budget conversations.
SELECT
    department,
    COUNT(*)               AS total_patients,
    SUM(treatment_cost)    AS total_revenue,
    ROUND(AVG(treatment_cost), 2) AS avg_cost_per_patient
FROM clean_patient_records
GROUP BY department
ORDER BY total_revenue DESC;


-- 4.2 Average length of stay by department — useful for spotting
--     departments where patients are staying longer than expected.
SELECT
    department,
    ROUND(AVG(length_of_stay_days), 1) AS avg_length_of_stay_days
FROM clean_patient_records
WHERE status = 'Discharged'   -- only counts patients who've actually left
GROUP BY department
ORDER BY avg_length_of_stay_days DESC;


-- 4.3 Most common diagnoses overall — helps with staffing and
--     supply planning (e.g. do we need more orthopedic capacity?).
SELECT
    diagnosis,
    COUNT(*) AS number_of_cases
FROM clean_patient_records
GROUP BY diagnosis
ORDER BY number_of_cases DESC
LIMIT 5;


-- 4.4 Doctor workload — how many patients has each doctor handled,
--     and how much revenue is tied to their department's cases?
SELECT
    doctor_name,
    department,
    COUNT(*)             AS patients_treated,
    SUM(treatment_cost)  AS total_revenue_generated
FROM clean_patient_records
GROUP BY doctor_name, department
ORDER BY patients_treated DESC;


-- 4.5 Revenue split by insurance provider — relevant for finance
--     teams reconciling payments with NHIS vs. private insurers.
SELECT
    insurance_provider,
    COUNT(*)             AS total_patients,
    SUM(treatment_cost)  AS total_revenue
FROM clean_patient_records
GROUP BY insurance_provider
ORDER BY total_revenue DESC;


-- 4.6 Currently admitted patients — a live snapshot of who's still
--     in the hospital right now (no discharge date yet).
SELECT
    patient_name,
    department,
    doctor_name,
    admission_date,
    DATEDIFF(CURDATE(), admission_date) AS days_admitted_so_far
FROM clean_patient_records
WHERE status = 'Admitted'
ORDER BY admission_date;


-- 4.7 Monthly admissions trend — helps spot seasonal spikes
--     (flu season, holidays, etc.) at a glance.
SELECT
    DATE_FORMAT(admission_date, '%Y-%m-01') AS month,
    COUNT(*) AS total_admissions
FROM clean_patient_records
GROUP BY 1
ORDER BY 1;

/* ============================================================
   END OF PROJECT
   ============================================================ */
