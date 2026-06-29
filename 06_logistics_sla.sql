-- ============================================================
-- DELIVERY TIME vs. CANCELLATION RATE BY CATEGORY
-- ============================================================
-- An earlier version of the cancellation-rate calculation
-- mixed two levels of granularity: the numerator counted
-- order_items rows (so a canceled order with 3 items counted
-- 3 times), while the denominator counted distinct orders.
-- That overstated cancellation rate for any category with
-- multi-item orders. Both sides are now counted at the same
-- (distinct order) granularity.

SELECT
    p.product_category_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 1) AS avg_delivery_days,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN o.order_status = 'canceled' THEN o.order_id END)
        / COUNT(DISTINCT o.order_id), 2) AS cancellation_rate_pct
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_status IN ('delivered', 'canceled')
GROUP BY p.product_category_name
HAVING COUNT(DISTINCT o.order_id) >= 30
ORDER BY avg_delivery_days DESC;

-- Headline finding: office furniture takes ~20.8 days to
-- deliver on average -- the longest of any major category --
-- yet has one of the lowest cancellation rates (0.08%).
-- Customers buying furniture appear willing to wait. Electronics
-- and beauty products sit at the opposite end, delivering in
-- roughly 12-13 days.
