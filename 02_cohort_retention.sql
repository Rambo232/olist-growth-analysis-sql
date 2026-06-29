-- ============================================================
-- COHORT RETENTION (weighted)
-- ============================================================
-- A first version of this query used a plain AVG() across
-- cohort retention percentages. That let cohorts of 1-2 people
-- (Sep and Dec 2016) carry the same weight as cohorts of
-- 7,000+, inflating month-1 retention to ~5.4%. This version
-- weights by actual cohort size and excludes cohorts under 50
-- customers as statistically unreliable.

WITH first_purchase AS (
    -- Month of each customer's first delivered order.
    SELECT
        c.customer_unique_id,
        DATE_FORMAT(MIN(o.order_purchase_timestamp), '%Y-%m-01') AS cohort_month
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
activity AS (
    -- Every month in which each customer was active.
    SELECT
        c.customer_unique_id,
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01') AS activity_month
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
cohort_size AS (
    -- Cohort sizes, excluding cohorts too small to be reliable.
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS cohort_customers
    FROM first_purchase
    GROUP BY cohort_month
    HAVING COUNT(DISTINCT customer_unique_id) >= 50
),
retention_raw AS (
    -- Active customers per cohort, per month-since-acquisition.
    SELECT
        f.cohort_month,
        TIMESTAMPDIFF(MONTH, f.cohort_month, a.activity_month) AS month_number,
        COUNT(DISTINCT a.customer_unique_id) AS active_customers
    FROM first_purchase f
    JOIN activity a ON f.customer_unique_id = a.customer_unique_id
    GROUP BY f.cohort_month, month_number
),
months AS (
    SELECT DISTINCT month_number FROM retention_raw WHERE month_number BETWEEN 1 AND 12
)
-- Weighted average: total returners across all cohorts divided
-- by total cohort base, instead of averaging pre-computed
-- per-cohort percentages.
SELECT
    m.month_number,
    COUNT(DISTINCT cs.cohort_month) AS cohorts_count,
    SUM(cs.cohort_customers) AS total_cohort_base,
    SUM(COALESCE(r.active_customers, 0)) AS total_active,
    ROUND(100.0 * SUM(COALESCE(r.active_customers, 0)) / SUM(cs.cohort_customers), 3) AS weighted_retention_pct
FROM cohort_size cs
CROSS JOIN months m
LEFT JOIN retention_raw r ON r.cohort_month = cs.cohort_month AND r.month_number = m.month_number
GROUP BY m.month_number
ORDER BY m.month_number;

-- Headline result: month-1 retention = 0.450%, not the ~5.4%
-- a naive unweighted average would suggest.
