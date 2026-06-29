-- ============================================================
-- CATEGORY ECONOMICS
-- ============================================================
-- Revenue, freight burden, and average order value by product
-- category. Categories with fewer than 30 orders are excluded
-- as too small a sample to draw conclusions from.

SELECT
    p.product_category_name,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.price) AS total_price,
    SUM(oi.freight_value) AS total_freight,
    ROUND(100.0 * SUM(oi.freight_value) / SUM(oi.price), 2) AS freight_pct,
    ROUND(SUM(oi.price) / COUNT(DISTINCT oi.order_id), 2) AS avg_order_value
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_category_name
HAVING COUNT(DISTINCT oi.order_id) >= 30
ORDER BY total_price DESC;

-- Headline finding: "computers" carries the highest average
-- order value (1,231.84) at the lowest freight share (4.41%)
-- of any major category. Note this is specifically the
-- "computers" category -- the separate "electronics" category
-- has an almost opposite profile (AOV 62.84, freight 29.07%)
-- and the two should not be conflated when reporting this.
--
-- Second finding: furniture/home categories (furniture_decor
-- 23.67%, housewares 23.12%, office_furniture 25.03%) all sit
-- in a 20-25% freight-to-price band, roughly 5x the share paid
-- on computers.
