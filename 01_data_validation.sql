-- ============================================================
-- DATA VALIDATION
-- Sanity checks performed before trusting any metric in this
-- project. Each check either confirmed a working assumption or
-- caught a real bug before it reached a final query.
-- ============================================================

-- Check 1: customer_id vs customer_unique_id
-- customer_id is generated per ORDER, not per PERSON. Grouping
-- cohorts by it would show retention of ~0% by construction,
-- since the same person gets a new customer_id on every order.
SELECT
    COUNT(DISTINCT customer_id) AS unique_order_customer_ids,
    COUNT(DISTINCT customer_unique_id) AS unique_real_customers
FROM customers;
-- Result: 99441 vs 96096 -- confirmed the two IDs are not
-- interchangeable. customer_unique_id is used everywhere below.


-- Check 2: is order data complete through the end of the
-- observed window, or does it look censored (i.e. cut off
-- mid-export rather than reflecting a real business slowdown)?
SELECT
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m-01') AS month,
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN order_status = 'delivered' THEN 1 END) AS delivered_orders,
    ROUND(100.0 * COUNT(CASE WHEN order_status = 'delivered' THEN 1 END) / COUNT(*), 1) AS delivered_pct
FROM orders
GROUP BY month
ORDER BY month DESC
LIMIT 6;
-- Result: delivered_pct stays at 97-99% through Aug 2018, then
-- drops near zero for Sep/Oct 2018 -- the export was taken in
-- early September 2018. Analysis window capped at August 2018
-- in every query below.


-- Check 3: is freight_value duplicated across multi-item orders?
-- Tested at three levels of granularity (order, order+seller,
-- order+product) before concluding it is not.
SELECT
    oi.order_id,
    oi.seller_id,
    oi.product_id,
    COUNT(*) AS units_of_this_product,
    COUNT(DISTINCT oi.freight_value) AS distinct_freight_per_product
FROM order_items oi
GROUP BY oi.order_id, oi.seller_id, oi.product_id
HAVING COUNT(*) > 1
ORDER BY units_of_this_product DESC
LIMIT 20;
-- Result: distinct_freight_per_product = 1 for every row tested.
-- freight_value is charged per unit of a given product, not
-- duplicated by mistake. SUM(price + freight_value) per order
-- is correct as-is -- no deduplication needed.


-- Check 4: does literally every customer buy exactly once?
-- (Full RFM logic lives in 07_rfm_segmentation.sql -- this is
-- just the distribution check.)
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
-- Result: 90,557 customers with frequency 1, but 2,573 with 2,
-- 181 with 3, down to one customer with 15. 97.0% one-time,
-- 3.0% repeat -- not the 100% one-time claim that a separate
-- AI-generated analysis of this same dataset had concluded.


-- Check 5: does repeat-purchase rate vary sharply by state?
-- A popular write-up of this dataset on Kaggle claims Sao Paulo
-- (SP) shows a "record low" ~6% repeat rate while remote states
-- like Rondonia (RO) exceed 10%. Tested directly.
SELECT
    cust.customer_state,
    COUNT(DISTINCT cust.customer_unique_id) AS total_customers,
    COUNT(DISTINCT CASE WHEN oc.frequency >= 2 THEN cust.customer_unique_id END) AS repeat_customers,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN oc.frequency >= 2 THEN cust.customer_unique_id END)
        / COUNT(DISTINCT cust.customer_unique_id), 2) AS repeat_rate_pct
FROM customers cust
JOIN (
    SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS frequency
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
) oc ON cust.customer_unique_id = oc.customer_unique_id
GROUP BY cust.customer_state
HAVING COUNT(DISTINCT cust.customer_unique_id) >= 100
ORDER BY total_customers DESC;
-- Result: SP repeat rate is 3.14% -- right at the platform
-- average (3.0%), not a record low. RO is higher at 4.33%, but
-- nowhere near the claimed 10%+. The claimed pattern does not
-- hold; SP's 42% share of the customer base is the only part
-- of that claim confirmed.
