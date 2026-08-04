/* ============================================================
   OLIST TWO-SIDED MARKETPLACE ANALYTICS
   Seller Health x Customer Behavior Analysis
   Platform: Databricks SQL (Delta Lake)
   Author: Anipireddy Venkata Sai Reddy
   ============================================================

   Business Question:
   Which sellers pose delivery/satisfaction risk to the marketplace,
   how do customers behave (RFM, loyalty, satisfaction), and does
   seller health actually affect customer loyalty/satisfaction?

   Data Source: Brazilian E-Commerce Public Dataset by Olist (Kaggle)
   ============================================================ */

/* ============================================================
    DATA CLEANING
   ============================================================ */

-- 2.1 Sanity check: delivered-before-purchased orders (found: 0 rows)
SELECT COUNT(*) AS bad_rows
FROM orders
WHERE order_delivered_customer_date < order_purchase_timestamp;

-- 2.2 Sanity check: "delivered" orders missing a delivery date (found: 8 rows)
SELECT COUNT(*) AS missing_delivery_dates
FROM orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL;

-- 2.3 Sanity check: duplicate order_items rows (found: 0 rows)
SELECT order_id, order_item_id, COUNT(*) AS cnt
FROM order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

-- 2.4 Sanity check: orders with no matching customer (found: 0 rows)
SELECT COUNT(*)
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- 2.5 Sanity check: duplicate reviews per order
--     Found: 104,162 total reviews vs 99,742 unique orders -> 4,420 duplicate rows
SELECT COUNT(*) AS total_reviews, COUNT(DISTINCT order_id) AS unique_orders_with_reviews
FROM order_reviews;

-- 2.6 Fix: dedupe reviews, keep latest review per order
CREATE OR REPLACE TABLE reviews_dedup AS
SELECT * FROM (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY review_answer_timestamp DESC) AS rn
  FROM order_reviews
) WHERE rn = 1;

-- Verify dedupe worked (both counts should now match)
SELECT COUNT(*) AS total, COUNT(DISTINCT order_id) AS unique_orders
FROM reviews_dedup;

-- 2.7 Note on customer_id vs customer_unique_id:
-- customer_id is order-scoped (a new one is generated per order),
-- customer_unique_id identifies the actual person. Always use
-- customer_unique_id for any repeat-purchase / loyalty analysis.
SELECT COUNT(DISTINCT customer_id) AS unique_customer_id,
       COUNT(DISTINCT customer_unique_id) AS unique_customer_unique_id
FROM customers;

-- 2.8 Build a filtered table for delivery-timing analysis only.
--     (Keep using the full `orders` table for revenue/count metrics.)
CREATE OR REPLACE TABLE orders_delivered AS
SELECT *
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_delivered_customer_date >= order_purchase_timestamp;


/* ============================================================
   SELLER-SIDE ANALYSIS
   ============================================================
   NOTE: seller_health was originally built with a bug -- joining
   an order-level on-time flag against row-level order_items caused
   on_time_pct to exceed 100% for sellers with multi-item orders.
   Fixed by aggregating on-time %, review score, and revenue in
   separate CTEs at the correct grain, then joining the already
   -aggregated results together. Version below is the corrected one.
   ============================================================ */

CREATE OR REPLACE TABLE seller_health AS
WITH order_level AS (
  -- one row per seller + order, so on-time % isn't inflated by
  -- orders that contain multiple items
  SELECT DISTINCT
    oi.seller_id,
    od.order_id,
    CASE WHEN od.order_delivered_customer_date <= od.order_estimated_delivery_date
         THEN 1 ELSE 0 END AS on_time_flag
  FROM order_items oi
  JOIN orders_delivered od ON oi.order_id = od.order_id
),
seller_delivery AS (
  SELECT seller_id,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(100.0 * SUM(on_time_flag) / COUNT(DISTINCT order_id), 2) AS on_time_pct
  FROM order_level
  GROUP BY seller_id
),
seller_reviews AS (
  SELECT oi.seller_id, ROUND(AVG(r.review_score), 2) AS avg_review_score
  FROM order_items oi
  LEFT JOIN reviews_dedup r ON oi.order_id = r.order_id
  GROUP BY oi.seller_id
),
seller_revenue AS (
  SELECT seller_id,
    ROUND(SUM(price), 2) AS total_revenue,
    ROUND(SUM(freight_value) / NULLIF(SUM(price), 0), 2) AS freight_to_price_ratio
  FROM order_items
  GROUP BY seller_id
)
SELECT
  sd.seller_id,
  sd.total_orders,
  sd.on_time_pct,
  sr.avg_review_score,
  srev.total_revenue,
  srev.freight_to_price_ratio
FROM seller_delivery sd
LEFT JOIN seller_reviews sr ON sd.seller_id = sr.seller_id
LEFT JOIN seller_revenue srev ON sd.seller_id = srev.seller_id;

-- Sanity check: avg_on_time_pct must be <= 100
SELECT COUNT(*) AS total_sellers,
       ROUND(AVG(on_time_pct),2) AS avg_on_time_pct,
       ROUND(AVG(avg_review_score),2) AS avg_review_score
FROM seller_health;

-- 3.1 Revenue concentration by decile (marketplace dependency risk)
CREATE OR REPLACE TABLE seller_concentration AS
WITH ranked AS (
  SELECT seller_id, total_revenue,
    NTILE(10) OVER (ORDER BY total_revenue DESC) AS decile
  FROM seller_health
)
SELECT decile,
  SUM(total_revenue) AS revenue,
  ROUND(100.0 * SUM(total_revenue) / SUM(SUM(total_revenue)) OVER (), 2) AS pct_of_total
FROM ranked
GROUP BY decile
ORDER BY decile;

-- 3.2 Seller risk flags
CREATE OR REPLACE TABLE seller_risk_flags AS
SELECT *,
  CASE WHEN on_time_pct < 80 AND avg_review_score < 3.5 AND total_orders > 5
       THEN 'At Risk' ELSE 'Healthy' END AS seller_status
FROM seller_health;

-- 3.3 Risk breakdown summary
SELECT seller_status, COUNT(*) AS seller_count, ROUND(AVG(total_revenue),2) AS avg_revenue
FROM seller_risk_flags
GROUP BY seller_status;


/* ============================================================
   CUSTOMER-SIDE ANALYSIS
   ============================================================ */

-- 4.1 Customer RFM (Recency, Frequency, Monetary)
CREATE OR REPLACE TABLE customer_rfm AS
WITH customer_orders AS (
  SELECT
    c.customer_unique_id,
    o.order_id,
    o.order_purchase_timestamp,
    op.payment_value
  FROM orders o
  JOIN customers c ON o.customer_id = c.customer_id
  JOIN order_payments op ON o.order_id = op.order_id
  WHERE o.order_status = 'delivered'
)
SELECT
  customer_unique_id,
  DATEDIFF(day, MAX(order_purchase_timestamp), (SELECT MAX(order_purchase_timestamp) FROM customer_orders)) AS recency_days,
  COUNT(DISTINCT order_id) AS frequency,
  ROUND(SUM(payment_value), 2) AS monetary
FROM customer_orders
GROUP BY customer_unique_id;

-- 4.2 Customer segmentation
CREATE OR REPLACE TABLE customer_segments AS
SELECT *,
  CASE
    WHEN frequency > 1 AND recency_days < 90 THEN 'Loyal'
    WHEN frequency > 1 AND recency_days >= 90 THEN 'At-Risk Repeat'
    WHEN frequency = 1 AND recency_days < 90 THEN 'New'
    ELSE 'Lapsed'
  END AS customer_segment
FROM customer_rfm;

-- 4.3 Segment summary
-- Result: Lapsed 72,711 | New 17,845 | At-Risk Repeat 2,187 | Loyal 614
-- Repeat purchase rate ~3% of all customers; repeat customers spend ~2x more
SELECT customer_segment, COUNT(*) AS customer_count, ROUND(AVG(monetary),2) AS avg_spend
FROM customer_segments
GROUP BY customer_segment
ORDER BY customer_count DESC;

-- 4.4 Satisfaction vs delivery timeliness
-- Result: On-Time avg review 4.29 (88,163 orders) | Late avg review 2.57 (7,661 orders)
CREATE OR REPLACE TABLE satisfaction_by_delivery AS
SELECT
  CASE
    WHEN od.order_delivered_customer_date <= od.order_estimated_delivery_date THEN 'On-Time'
    ELSE 'Late'
  END AS delivery_status,
  ROUND(AVG(r.review_score), 2) AS avg_review_score,
  COUNT(*) AS order_count
FROM orders_delivered od
JOIN reviews_dedup r ON od.order_id = r.order_id
GROUP BY delivery_status;


/* ============================================================
   BRIDGE ANALYSIS -- Seller Health -> Customer Outcomes
   ============================================================
   NOTE: this table is item-weighted, not order-weighted, since it
   joins through order_items (a seller with many multi-item orders
   contributes more rows). Treated as an acceptable simplification
   for this analysis.
   ============================================================ */

CREATE OR REPLACE TABLE seller_customer_impact AS
SELECT
  srf.seller_status,
  COUNT(DISTINCT cs.customer_unique_id) AS customers_affected,
  ROUND(AVG(r.review_score), 2) AS avg_review_score,
  ROUND(100.0 * SUM(CASE WHEN cs.customer_segment = 'Loyal' THEN 1 ELSE 0 END)
        / COUNT(DISTINCT cs.customer_unique_id), 2) AS pct_loyal_customers
FROM seller_risk_flags srf
JOIN order_items oi ON srf.seller_id = oi.seller_id
JOIN orders o ON oi.order_id = o.order_id
JOIN customers c ON o.customer_id = c.customer_id
JOIN customer_segments cs ON c.customer_unique_id = cs.customer_unique_id
LEFT JOIN reviews_dedup r ON o.order_id = r.order_id
GROUP BY srf.seller_status;

-- Result:
-- Healthy sellers: 92,425 customers | avg review 4.09 | 1.79% loyal
-- At Risk sellers:  1,007 customers | avg review 3.07 | 1.89% loyal
-- Finding: At-Risk sellers show clearly lower satisfaction, but loyalty
-- conversion is nearly identical -- overall platform loyalty (~2%) is
-- low enough that individual seller experience isn't the primary driver
-- of repeat purchase behavior.
SELECT * FROM seller_customer_impact;
