-- ============================================================
-- MONTH-OVER-MONTH REVENUE GROWTH (gap-filled calendar)
-- ============================================================
-- A first version of this query grouped revenue by month and
-- compared each row to LAG(). That silently breaks when a
-- calendar month has zero delivered orders -- LAG() then
-- compares against the wrong neighbour (e.g. December 2016
-- against October 2016, skipping over the missing November),
-- reporting a "month-over-month" change that actually spans
-- two months. The recursive CTE below generates every calendar
-- month explicitly, with zero-order months filled in as 0
-- revenue rather than silently dropped.

WITH RECURSIVE month_series AS (
    -- Generate one row per calendar month across the full
    -- observed range.
    SELECT DATE_FORMAT(MIN(order_purchase_timestamp), '%Y-%m-01') AS month
    FROM orders WHERE order_status = 'delivered'
    UNION ALL
    SELECT DATE_ADD(month, INTERVAL 1 MONTH)
    FROM month_series
    WHERE month < (
        SELECT DATE_FORMAT(MAX(order_purchase_timestamp), '%Y-%m-01')
        FROM orders WHERE order_status = 'delivered'
    )
),
monthly_revenue AS (
    -- Actual revenue and order count per month that had orders.
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01') AS month,
        SUM(oi.price + oi.freight_value) AS revenue,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY month
),
filled AS (
    -- Left join onto the full calendar so empty months become
    -- explicit zero rows instead of disappearing.
    SELECT
        ms.month,
        COALESCE(mr.revenue, 0) AS revenue,
        COALESCE(mr.order_count, 0) AS order_count
    FROM month_series ms
    LEFT JOIN monthly_revenue mr ON ms.month = mr.month
)
SELECT
    month,
    order_count,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
    CASE
        WHEN LAG(revenue) OVER (ORDER BY month) IS NULL THEN NULL
        WHEN LAG(revenue) OVER (ORDER BY month) = 0 THEN NULL
        ELSE ROUND(
            (revenue - LAG(revenue) OVER (ORDER BY month))
            / LAG(revenue) OVER (ORDER BY month) * 100, 1
        )
    END AS mom_growth_pct
FROM filled
ORDER BY month;

-- Reading note: 2016 figures (Sep-Dec) involve order counts in
-- the single digits -- month-over-month percentages there are
-- mathematically correct but not business-meaningful. Treat
-- the series as informative starting February 2017.
