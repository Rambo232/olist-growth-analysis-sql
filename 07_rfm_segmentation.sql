-- ============================================================
-- CUSTOMER-LEVEL RFM SEGMENTATION
-- ============================================================
-- Grouping by customers.customer_id (the per-order ID) instead
-- of customer_unique_id would force frequency = 1 for nearly
-- every row by construction, regardless of actual repeat-buying
-- behaviour. This was the exact mistake found in an
-- independently generated analysis of this dataset, whose
-- headline claim of "100% one-time customers" does not survive
-- the corrected query below.

-- Step 1: real frequency distribution per person, not per order.
SELECT frequency, COUNT(*) AS customers_count
FROM (
    SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS frequency
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
) t
GROUP BY frequency
ORDER BY frequency;
-- Result: 90,557 customers at frequency 1; 2,573 at frequency 2;
-- down to a single customer at frequency 15. 97.0% one-time,
-- 3.0% repeat buyers -- a small but real loyal tail.

-- Step 2: full RFM. Recency is anchored to the dataset's own
-- last order date, not real CURRENT_DATE() -- the data is
-- historical, not live, so anchoring to today would inflate
-- every recency value by the same constant offset. Harmless for
-- relative ranking, but misleading if read as an absolute
-- number of days.
WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_order_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price + oi.freight_value) AS monetary_value
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
max_date AS (
    SELECT MAX(order_purchase_timestamp) AS global_last_date
    FROM orders WHERE order_status = 'delivered'
)
SELECT
    r.customer_unique_id,
    TIMESTAMPDIFF(DAY, r.last_order_date, m.global_last_date) AS recency_days,
    r.frequency,
    r.monetary_value,
    -- Champion: repeat buyer, active recently.
    -- Returning, inactive: repeat buyer, but it's been a while.
    -- New / recent one-timer: bought once, recently -- too early
    --   to know if they'll return.
    -- Lost: bought once, a long time ago.
    CASE
        WHEN r.frequency >= 2 AND TIMESTAMPDIFF(DAY, r.last_order_date, m.global_last_date) < 90 THEN 'Champion'
        WHEN r.frequency >= 2 THEN 'Returning, inactive'
        WHEN TIMESTAMPDIFF(DAY, r.last_order_date, m.global_last_date) < 90 THEN 'New / recent one-timer'
        ELSE 'Lost'
    END AS customer_grade
FROM customer_rfm r
CROSS JOIN max_date m
ORDER BY r.monetary_value DESC;

-- Use: the "Champion" segment is small (frequency >= 2, active
-- within 90 days) but represents the platform's only genuinely
-- loyal customers -- worth a dedicated retention play rather
-- than being averaged away into "nobody returns."
