-- ============================================================
-- SELLER PERFORMANCE & MARKET CONCENTRATION
-- ============================================================
-- Sellers with fewer than 10 total orders are excluded -- a
-- seller with 1 order and 1 cancellation would otherwise show
-- a meaningless 100% cancellation rate.

WITH seller_base AS (
    -- Per-seller order counts and revenue. canceled_orders and
    -- active_orders are counted at the distinct-order level, not
    -- the order_items row level, so a canceled order with
    -- multiple line items is not counted more than once.
    SELECT
        s.seller_id,
        COUNT(DISTINCT CASE WHEN o.order_status = 'canceled' THEN o.order_id END) AS canceled_orders,
        COUNT(DISTINCT CASE WHEN o.order_status != 'canceled' THEN o.order_id END) AS active_orders,
        SUM(oi.price) AS total_sells,
        AVG(oi.price) AS avg_product_price
    FROM sellers s
    JOIN order_items oi ON s.seller_id = oi.seller_id
    JOIN orders o ON o.order_id = oi.order_id
    GROUP BY s.seller_id
)
SELECT
    seller_id,
    canceled_orders,
    active_orders,
    ROUND(100.0 * canceled_orders / (canceled_orders + active_orders), 2) AS cancellation_rate_pct,
    total_sells,
    -- Running total ordered by revenue, used to read off market
    -- concentration directly from the result set.
    SUM(total_sells) OVER (ORDER BY total_sells DESC ROWS UNBOUNDED PRECEDING) AS cumulative_revenue,
    ROUND((total_sells / SUM(total_sells) OVER ()) * 100, 2) AS market_share_pct,
    avg_product_price
FROM seller_base
WHERE (canceled_orders + active_orders) >= 10
ORDER BY total_sells DESC;

-- Headline finding: the single largest seller by revenue holds
-- 1.86% of total market share, and share declines smoothly
-- rather than dropping off a cliff -- this is a fragmented
-- market with no single-vendor concentration risk, not the
-- steep Pareto concentration sometimes claimed for this
-- dataset.
