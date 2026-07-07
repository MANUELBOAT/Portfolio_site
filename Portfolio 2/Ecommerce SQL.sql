/* ============================================================
   E-COMMERCE SALES ANALYSIS — SQL PORTFOLIO PROJECT

   Structure:
     1. Schema design (raw + clean tables)
     2. Sample messy data (simulates a real export)
     3. Data cleaning pipeline
     4. Analysis queries (business questions + answers)
   ============================================================ */


/* ============================================================
   1. SCHEMA — RAW LAYER
   This mimics a messy export you'd typically get from a CRM,
   CSV upload
   ============================================================ */

DROP TABLE IF EXISTS raw_orders;

CREATE TABLE raw_orders (
    order_id        VARCHAR(20),
    customer_name   VARCHAR(100),
    customer_email  VARCHAR(100),
    product_name    VARCHAR(100),
    category        VARCHAR(50),
    quantity        VARCHAR(10),      
    unit_price      VARCHAR(20),      
    order_date      VARCHAR(20),      
    country         VARCHAR(50),
    status          VARCHAR(20)
);


/* ============================================================
   2. SAMPLE MESSY DATA
   Includes: duplicates, NULLs, inconsistent casing,
   inconsistent date formats, currency symbols, whitespace,
   and mixed country naming.
   ============================================================ */

INSERT INTO raw_orders VALUES
('ORD1001', 'John Smith',   'john.smith@email.com',  'Wireless Mouse',    'Electronics', '2',  '$19.99', '2024-01-05', 'USA',           'Completed'),
('ORD1002', ' jane doe ',   'JANE.DOE@email.com',    'bluetooth speaker', 'electronics', '1',  '49.99',  '01/06/2024', 'United States', 'completed'),
('ORD1003', 'Mike Brown',   NULL,                    'Yoga Mat',          'Fitness',     '3',  '$15.00', '2024-01-07', 'USA',           'Completed'),
('ORD1004', 'Sara Lee',     'sara.lee@email.com',    'Yoga Mat',          'fitness',     '3',  '15.00',  '2024-01-07', 'usa',           'Completed'),
('ORD1005', 'Tom Wu',       'tom.wu@email.com',      'Desk Lamp',         'Home',        NULL, '25.50',  '2024/01/08', 'Canada',        'Pending'),
('ORD1006', 'Anna Kim',     'anna.kim@email.com',    'Desk Lamp',         'Home',        '1',  '$25.50', '08-01-2024', 'Canada',        'Pending'),
('ORD1006', 'Anna Kim',     'anna.kim@email.com',    'Desk Lamp',         'Home',        '1',  '$25.50', '08-01-2024', 'Canada',        'Pending'),
('ORD1007', 'Liam Chen',    'liam.chen@email.com',   'Wireless Mouse',    'Electronics', '-1', '19.99',  '2024-01-09', 'UK',            'Cancelled'),
('ORD1008', 'Emma Davis',   'emma.davis@email.com',  'Bluetooth Speaker', 'Electronics', '2',  '49.99',  '2024-01-10', 'United Kingdom','Completed'),
('ORD1009', 'Noah Patel',   'noah.patel@email.com',  'Running Shoes',     'Fitness',     '1',  '89.99',  '2024-01-11', 'India',         'Completed'),
('ORD1010', 'Olivia Ruiz',  'olivia.ruiz@email.com', 'Running Shoes',     'fitness',     '1',  '$89.99', '11/01/2024', 'india',         'completed'),
('ORD1011', 'James Park',   'james.park@email.com',  NULL,                'Electronics', '1',  '15.00',  '2024-01-12', 'USA',           'Completed'),
('ORD1012', 'Grace Ho',     'grace.ho@email.com',    'Water Bottle',      'Fitness',     '5',  '9.99',   '2024-01-13', 'USA',           'Completed'),
('ORD1013', 'Grace Ho',     'grace.ho@email.com',    'Water Bottle',      'Fitness',     '5',  '9.99',   '2024-01-13', 'USA',           'Completed'),
('ORD1014', 'Ben Turner',   'ben.turner@email.com',  'Desk Lamp',         'Home',        '2',  'abc',    '2024-01-14', 'Canada',        'Completed');


/* ============================================================
   3. DATA CLEANING PIPELINE
   ============================================================ */


DROP TABLE IF EXISTS clean_orders;

CREATE TABLE clean_orders AS
WITH standardized AS (
    SELECT
        order_id,

        -- Trim + title-case customer name (first letter of each word)
        TRIM(customer_name)                                AS customer_name_raw,

        -- Lowercase + trim email for consistent joins/dedup
        LOWER(TRIM(customer_email))                        AS customer_email,

        -- Trim product name (title-cased below in final select)
        TRIM(product_name)                                 AS product_name_raw,

        -- Trim category (title-cased below in final select)
        TRIM(category)                                     AS category_raw,

        -- Quantity: cast safely, treat negative/NULL/non-numeric as unknown (NULL)
        CASE
            WHEN quantity REGEXP '^[0-9]+$' AND CAST(quantity AS SIGNED) > 0
                THEN CAST(quantity AS SIGNED)
            ELSE NULL
        END                                                 AS quantity,

        -- Unit price: strip everything except digits and '.', validate, else NULL
        CASE
            WHEN REGEXP_REPLACE(unit_price, '[^0-9.]', '') REGEXP '^[0-9]+(\\.[0-9]+)?$'
                THEN CAST(REGEXP_REPLACE(unit_price, '[^0-9.]', '') AS DECIMAL(10,2))
            ELSE NULL
        END                                                 AS unit_price,

        -- Order date: try multiple incoming formats -> DATE
        COALESCE(
            STR_TO_DATE(NULLIF(order_date, ''), '%Y-%m-%d'),
            STR_TO_DATE(NULLIF(order_date, ''), '%m/%d/%Y'),
            STR_TO_DATE(NULLIF(order_date, ''), '%Y/%m/%d'),
            STR_TO_DATE(NULLIF(order_date, ''), '%d-%m-%Y')
        )                                                   AS order_date,

        -- Standardize country naming
        CASE
            WHEN LOWER(TRIM(country)) IN ('usa', 'united states', 'us') THEN 'United States'
            WHEN LOWER(TRIM(country)) IN ('uk', 'united kingdom') THEN 'United Kingdom'
            WHEN LOWER(TRIM(country)) = 'india' THEN 'India'
            WHEN LOWER(TRIM(country)) = 'canada' THEN 'Canada'
            ELSE TRIM(country)
        END                                                 AS country,

        -- Status (title-cased below in final select)
        TRIM(status)                                        AS status_raw,

        -- Row rank to detect exact duplicate rows (ignoring order_id)
        ROW_NUMBER() OVER (
            PARTITION BY
                LOWER(TRIM(customer_email)),
                LOWER(TRIM(product_name)),
                order_date,
                quantity,
                unit_price
            ORDER BY order_id
        ) AS dup_rank

    FROM raw_orders
    WHERE product_name IS NOT NULL          -- drop rows with no product identified
      AND customer_email IS NOT NULL        -- drop rows with no way to identify the customer
)

SELECT
    order_id,

    -- Manual title-case: first letter upper, rest lower, per word
    TRIM(CONCAT(
        UCASE(LEFT(customer_name_raw, 1)),
        LCASE(SUBSTRING(customer_name_raw, 2))
    ))                                                  AS customer_name,

    customer_email,

    TRIM(CONCAT(
        UCASE(LEFT(product_name_raw, 1)),
        LCASE(SUBSTRING(product_name_raw, 2))
    ))                                                  AS product_name,

    TRIM(CONCAT(
        UCASE(LEFT(category_raw, 1)),
        LCASE(SUBSTRING(category_raw, 2))
    ))                                                  AS category,

    quantity,
    unit_price,
    order_date,
    country,

    TRIM(CONCAT(
        UCASE(LEFT(status_raw, 1)),
        LCASE(SUBSTRING(status_raw, 2))
    ))                                                  AS status,

    ROUND(quantity * unit_price, 2)                    AS total_amount

FROM standardized
WHERE dup_rank = 1              -- remove exact duplicate rows
  AND quantity IS NOT NULL      -- drop invalid quantities
  AND unit_price IS NOT NULL    -- drop invalid/corrupted prices
  AND order_date IS NOT NULL;   -- drop unparseable dates


-- 3.1 Quick QA check: compare row counts before/after cleaning
SELECT
    (SELECT COUNT(*) FROM raw_orders)   AS raw_row_count,
    (SELECT COUNT(*) FROM clean_orders) AS clean_row_count;


/* ============================================================
   4. ANALYSIS QUERIES
   ============================================================ */

-- 4.1 Total revenue and order count by month
SELECT
    DATE_FORMAT(order_date, '%Y-%m-01') AS month,
    COUNT(DISTINCT order_id)            AS total_orders,
    SUM(total_amount)                   AS total_revenue
FROM clean_orders
WHERE status = 'Completed'
GROUP BY 1
ORDER BY 1;


-- 4.2 Top 5 best-selling products by revenue
SELECT
    product_name,
    SUM(quantity)      AS units_sold,
    SUM(total_amount)  AS revenue
FROM clean_orders
WHERE status = 'Completed'
GROUP BY product_name
ORDER BY revenue DESC
LIMIT 5;


-- 4.3 Revenue by category and country
SELECT
    category,
    country,
    SUM(total_amount) AS revenue
FROM clean_orders
WHERE status = 'Completed'
GROUP BY category, country
ORDER BY category, revenue DESC;


-- 4.4 Average order value (AOV)
SELECT
    ROUND(SUM(total_amount) / COUNT(DISTINCT order_id), 2) AS avg_order_value
FROM clean_orders
WHERE status = 'Completed';


-- 4.5 Repeat customer rate
-- (MySQL has no FILTER clause, so SUM(CASE WHEN...) is used instead)
WITH order_counts AS (
    SELECT customer_email, COUNT(DISTINCT order_id) AS orders_made
    FROM clean_orders
    WHERE status = 'Completed'
    GROUP BY customer_email
)
SELECT
    SUM(CASE WHEN orders_made > 1 THEN 1 ELSE 0 END) / COUNT(*) * 100
        AS repeat_customer_rate_pct
FROM order_counts;


-- 4.6 Simple RFM-style customer segmentation
--     (Recency, Frequency, Monetary — common e-commerce analysis)
WITH customer_stats AS (
    SELECT
        customer_email,
        MAX(order_date)                    AS last_order_date,
        COUNT(DISTINCT order_id)           AS frequency,
        SUM(total_amount)                  AS monetary
    FROM clean_orders
    WHERE status = 'Completed'
    GROUP BY customer_email
),
scored AS (
    SELECT
        customer_email,
        last_order_date,
        frequency,
        monetary,
        NTILE(4) OVER (ORDER BY last_order_date DESC) AS recency_score,  -- 1 = most recent
        NTILE(4) OVER (ORDER BY frequency DESC)       AS frequency_score,
        NTILE(4) OVER (ORDER BY monetary DESC)        AS monetary_score
    FROM customer_stats
)
SELECT
    customer_email,
    last_order_date,
    frequency,
    monetary,
    recency_score,
    frequency_score,
    monetary_score,
    CASE
        WHEN recency_score = 1 AND frequency_score = 1 THEN 'Champion'
        WHEN recency_score <= 2 AND frequency_score <= 2 THEN 'Loyal Customer'
        WHEN recency_score >= 3 AND frequency_score >= 3 THEN 'At Risk'
        ELSE 'Needs Attention'
    END AS customer_segment
FROM scored
ORDER BY monetary DESC;


-- 4.7 Order status breakdown (funnel / fulfillment view)
SELECT
    status,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 1) AS pct_of_total
FROM clean_orders
GROUP BY status
ORDER BY order_count DESC;

/* ============================================================
   END OF PROJECT
   Portfolio notes:
   - Requires MySQL 8.0+ for CTEs and window functions
     (ROW_NUMBER, NTILE).
   - Swap raw_orders with a real CSV import (LOAD DATA INFILE)
     to make this a live, end-to-end project.
   - Consider adding an ERD screenshot and a short README
     describing the business questions each query answers.
   ============================================================ */