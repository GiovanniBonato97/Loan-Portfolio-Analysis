-- ============================================================
-- Consumer Loan Portfolio Analysis
-- Author: Giovanni Bonato
-- Tool:   SQLite (DB Browser for SQLite)
-- Data:   bank_loan_data – 10,000 consumer loans (2007–2015),
--         imported as table NewTable (one row per loan)
--
-- Business questions:
--   1. What are customers borrowing for, and on what terms?
--   2. How are loans priced, and does pricing reflect credit risk?
--   3. Where (state, grade, purpose, term) is default risk concentrated?
--   4. How much money is exposed to defaulted loans?
--
-- Definitions:
--   Default    = default_flag = 1 (loan_status 'Charged Off' or 'Default')
--   Delinquent = loan_status 'In Grace Period' or 'Late (...)'
-- ============================================================


-- ------------------------------------------------------------
-- Section 0: Set-up
-- A view adds a clean 4-digit issue_year, so every query can
-- filter by year whatever date format the import produced
-- (e.g. '2015-01-08' or '1/8/15').
-- ------------------------------------------------------------

DROP VIEW IF EXISTS loans;

CREATE VIEW loans AS
SELECT
    *,
    CASE
        WHEN issue_date LIKE '____-%' THEN SUBSTR(issue_date, 1, 4)
        ELSE '20' || SUBSTR(issue_date, -2)
    END AS issue_year
FROM NewTable;


-- ------------------------------------------------------------
-- Section 1: Data overview
-- ------------------------------------------------------------

-- 1.1 Preview the data
SELECT *
FROM loans
LIMIT 10;

-- 1.2 Size of the portfolio
SELECT
    COUNT(*)                          AS total_loans,
    COUNT(DISTINCT addr_state)        AS states,
    MIN(issue_year)                   AS first_year,
    MAX(issue_year)                   AS last_year,
    SUM(funded_amnt)                  AS total_funded,
    ROUND(AVG(loan_amnt), 0)          AS avg_loan_amount,
    ROUND(100.0 * AVG(default_flag), 2) AS overall_default_rate_pct
FROM loans;


-- ------------------------------------------------------------
-- Section 2: Loan purpose
-- ------------------------------------------------------------

-- 2.1 Home improvement, car and medical loans issued in 2015
--     (exact match, so 'credit_card' is not counted as 'car')
SELECT
    purpose,
    COUNT(*) AS loan_count
FROM loans
WHERE issue_year = '2015'
  AND purpose IN ('home_improvement', 'car', 'medical')
GROUP BY purpose
ORDER BY loan_count DESC;

-- 2.2 Portfolio mix by purpose
SELECT
    purpose,
    COUNT(*)                                     AS loans,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct,
    ROUND(AVG(loan_amnt), 0)                     AS avg_loan_amount
FROM loans
GROUP BY purpose
ORDER BY loans DESC;


-- ------------------------------------------------------------
-- Section 3: Loan terms
-- ------------------------------------------------------------

-- 3.1 36- vs 60-month loans issued in 2014 and 2015
SELECT
    issue_year,
    TRIM(term)       AS term,
    COUNT(member_id) AS loan_count
FROM loans
WHERE issue_year IN ('2014', '2015')
GROUP BY issue_year, TRIM(term)
ORDER BY issue_year DESC, term;

-- 3.2 Default rate and interest rate by term
SELECT
    TRIM(term)                          AS term,
    COUNT(*)                            AS loans,
    ROUND(AVG(intrest_rate), 2)         AS avg_interest_rate,
    ROUND(100.0 * AVG(default_flag), 2) AS default_rate_pct
FROM loans
GROUP BY TRIM(term);


-- ------------------------------------------------------------
-- Section 4: Interest rates and risk-based pricing
-- ------------------------------------------------------------

-- 4.1 Average, highest and lowest interest rate for 2015 loans
SELECT
    ROUND(AVG(intrest_rate), 2) AS average_interest_rate,
    MAX(intrest_rate)           AS highest_interest_rate,
    MIN(intrest_rate)           AS lowest_interest_rate
FROM loans
WHERE issue_year = '2015';

-- 4.2 Interest rate vs default rate by credit grade
--     (is the extra interest charged in line with the extra risk?)
SELECT
    grade,
    COUNT(*)                            AS loans,
    ROUND(AVG(intrest_rate), 2)         AS avg_interest_rate,
    ROUND(100.0 * AVG(default_flag), 2) AS default_rate_pct
FROM loans
GROUP BY grade
ORDER BY grade;

-- 4.3 Loans by sub-grade
SELECT
    sub_grade,
    COUNT(*) AS total_loans
FROM loans
GROUP BY sub_grade
ORDER BY sub_grade;


-- ------------------------------------------------------------
-- Section 5: Loan volumes by state
-- ------------------------------------------------------------

-- 5.1 Loans issued per state in 2013 vs 2014
SELECT
    addr_state,
    issue_year,
    COUNT(*) AS loan_count
FROM loans
WHERE issue_year IN ('2013', '2014')
GROUP BY addr_state, issue_year
ORDER BY addr_state, issue_year;

-- 5.2 Growth in loans issued per state, 2013 to 2014
--     (states with at least 30 loans in 2013)
WITH state_year AS (
    SELECT
        addr_state,
        SUM(CASE WHEN issue_year = '2013' THEN 1 ELSE 0 END) AS loans_2013,
        SUM(CASE WHEN issue_year = '2014' THEN 1 ELSE 0 END) AS loans_2014
    FROM loans
    GROUP BY addr_state
)
SELECT
    addr_state,
    loans_2013,
    loans_2014,
    ROUND(100.0 * (loans_2014 - loans_2013) / loans_2013, 1) AS growth_pct
FROM state_year
WHERE loans_2013 >= 30
ORDER BY loans_2014 DESC;


-- ------------------------------------------------------------
-- Section 6: Delinquencies and defaults
-- ------------------------------------------------------------

-- 6.1 Number of loans in each problem status
SELECT
    loan_status,
    COUNT(*) AS loan_count
FROM loans
WHERE loan_status IN (
    'Charged Off',
    'Default',
    'In Grace Period',
    'Late (16-30 days)',
    'Late (31-120 days)')
GROUP BY loan_status
ORDER BY loan_count DESC;

-- 6.2 Default and delinquency rates by loan purpose
SELECT
    purpose,
    COUNT(*)                            AS loans,
    ROUND(100.0 * AVG(default_flag), 2) AS default_rate_pct,
    ROUND(100.0 * AVG(CASE WHEN loan_status = 'In Grace Period'
                             OR loan_status LIKE 'Late%'
                           THEN 1 ELSE 0 END), 2) AS delinquency_rate_pct
FROM loans
GROUP BY purpose
HAVING COUNT(*) >= 50
ORDER BY default_rate_pct DESC;

-- 6.3 Default rate by purpose: high-cost states vs other states
SELECT
    purpose,
    CASE
        WHEN addr_state IN ('CA', 'NY', 'FL', 'TX', 'NJ') THEN 'High-Cost State'
        ELSE 'Other States'
    END                                 AS state_category,
    COUNT(*)                            AS loans,
    ROUND(100.0 * AVG(default_flag), 2) AS default_rate_pct
FROM loans
GROUP BY purpose, state_category
HAVING COUNT(*) >= 30
ORDER BY purpose, state_category;


-- ------------------------------------------------------------
-- Section 7: Risk ranking and financial exposure
-- ------------------------------------------------------------

-- 7.1 Top 10 states by default rate (states with at least 100 loans)
WITH state_defaults AS (
    SELECT
        addr_state,
        COUNT(*)                    AS loans,
        100.0 * AVG(default_flag)   AS default_rate_pct
    FROM loans
    GROUP BY addr_state
    HAVING COUNT(*) >= 100
)
SELECT
    addr_state,
    loans,
    ROUND(default_rate_pct, 2)                  AS default_rate_pct,
    RANK() OVER (ORDER BY default_rate_pct DESC) AS risk_rank
FROM state_defaults
ORDER BY risk_rank
LIMIT 10;

-- 7.2 Money exposed to defaulted loans
--     (funded amount minus payments received, and how much was recovered)
SELECT
    COUNT(*)                                   AS defaulted_loans,
    SUM(funded_amnt)                           AS funded_amount,
    ROUND(SUM(total_pymnt), 0)                 AS paid_before_default,
    ROUND(SUM(funded_amnt - total_pymnt), 0)   AS unpaid_balance,
    ROUND(SUM(recoveries), 0)                  AS recoveries,
    ROUND(100.0 * SUM(recoveries)
          / SUM(funded_amnt - total_pymnt), 1) AS recovery_rate_pct
FROM loans
WHERE default_flag = 1;
