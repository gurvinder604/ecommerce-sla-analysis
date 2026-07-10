-- ============================================================
-- E-Commerce Delivery SLA Analysis
-- 8 Business Questions answered with SQL (SQLite)
-- Dataset: Olist Brazilian E-Commerce (96,470 delivered orders)
-- Author: Gurvinder Singh
-- ============================================================


-- ── Q1: Overall SLA Performance Summary ─────────────────────
-- Business question: What is the headline SLA performance?
-- Why first: Every other number is relative to this baseline.

SELECT
    COUNT(*)                                    AS total_orders,
    SUM(sla_breached)                           AS breached_orders,
    ROUND(AVG(sla_breached) * 100, 2)           AS breach_rate_pct,
    ROUND(AVG(days_vs_sla), 1)                  AS avg_days_vs_sla,
    ROUND(AVG(actual_days), 1)                  AS avg_actual_days,
    ROUND(AVG(promised_days), 1)                AS avg_promised_days,
    ROUND(MIN(days_vs_sla), 0)                  AS earliest_days,
    ROUND(MAX(days_vs_sla), 0)                  AS latest_days
FROM orders;


-- ── Q2: Breach Severity Breakdown ───────────────────────────
-- Business question: Of the 6.77% that breached, how bad were they?
-- Finding: 2.97% are severe (7+ days late), avg 19.6 days late.

SELECT
    breach_severity,
    COUNT(*)                                            AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)  AS pct_of_total,
    ROUND(AVG(days_vs_sla), 1)                          AS avg_days_vs_sla,
    ROUND(MIN(days_vs_sla), 0)                          AS min_days,
    ROUND(MAX(days_vs_sla), 0)                          AS max_days
FROM orders
GROUP BY breach_severity
ORDER BY
    CASE breach_severity
        WHEN 'On Time / Early'          THEN 1
        WHEN 'Minor (1-3 days late)'    THEN 2
        WHEN 'Moderate (4-7 days late)' THEN 3
        WHEN 'Severe (7+ days late)'    THEN 4
    END;


-- ── Q3: Monthly Breach Rate Trend ───────────────────────────
-- Business question: Is performance improving or deteriorating?
-- Finding: Improving overall; Q1 2018 spike to 18.96% at peak growth.

SELECT
    STRFTIME('%Y-%m', order_purchase_timestamp)     AS year_month,
    COUNT(*)                                        AS total_orders,
    SUM(sla_breached)                               AS breached_orders,
    ROUND(AVG(sla_breached) * 100, 2)               AS breach_rate_pct,
    ROUND(AVG(days_vs_sla), 1)                      AS avg_days_vs_sla
FROM orders
GROUP BY year_month
ORDER BY year_month;


-- ── Q4: Seller vs Carrier Time Split ────────────────────────
-- Business question: Where in the journey is time being lost?
-- Finding: Carrier time is 3.6x longer on breached orders than on-time.
-- Note: 1 order excluded due to missing carrier date (0.001%).

SELECT
    ROUND(AVG(seller_processing_days), 2)           AS avg_seller_days,
    ROUND(AVG(carrier_delivery_days), 2)            AS avg_carrier_days,
    ROUND(AVG(actual_days), 2)                      AS avg_total_days,
    ROUND(AVG(seller_processing_days) /
          AVG(actual_days) * 100, 1)                AS seller_pct_of_total,
    ROUND(AVG(carrier_delivery_days) /
          AVG(actual_days) * 100, 1)                AS carrier_pct_of_total,
    ROUND(AVG(CASE WHEN sla_breached = 1
          THEN seller_processing_days END), 2)      AS avg_seller_days_breached,
    ROUND(AVG(CASE WHEN sla_breached = 1
          THEN carrier_delivery_days END), 2)       AS avg_carrier_days_breached,
    ROUND(AVG(CASE WHEN sla_breached = 0
          THEN seller_processing_days END), 2)      AS avg_seller_days_ontime,
    ROUND(AVG(CASE WHEN sla_breached = 0
          THEN carrier_delivery_days END), 2)       AS avg_carrier_days_ontime
FROM orders
WHERE seller_processing_days IS NOT NULL
  AND carrier_delivery_days  IS NOT NULL;


-- ── Q5: Breach Rate by Seller State ─────────────────────────
-- Business question: Which regions have the worst SLA performance?
-- Finding: MA worst at 19.07%; only 3 of 13 states above platform average.
-- Filter: States with 100+ orders only (statistical reliability).

SELECT
    seller_state,
    COUNT(*)                                        AS total_orders,
    SUM(sla_breached)                               AS breached_orders,
    ROUND(AVG(sla_breached) * 100, 2)               AS breach_rate_pct,
    ROUND(AVG(days_vs_sla), 1)                      AS avg_days_vs_sla,
    ROUND(AVG(seller_processing_days), 1)           AS avg_seller_processing
FROM orders
WHERE seller_state IS NOT NULL
GROUP BY seller_state
HAVING COUNT(*) >= 100
ORDER BY breach_rate_pct DESC;


-- ── Q6: Top 10 Worst Performing Sellers ─────────────────────
-- Business question: Which specific sellers are driving breaches?
-- Finding: 8 of 10 worst sellers in SP; worst has 12.5 day processing time.
-- Filter: 20+ orders; multi-seller orders excluded to avoid misattribution.

SELECT
    seller_id,
    seller_state,
    COUNT(*)                                        AS total_orders,
    SUM(sla_breached)                               AS breached_orders,
    ROUND(AVG(sla_breached) * 100, 2)               AS breach_rate_pct,
    ROUND(AVG(seller_processing_days), 1)           AS avg_processing_days,
    ROUND(AVG(days_vs_sla), 1)                      AS avg_days_vs_sla
FROM orders
WHERE seller_id IS NOT NULL
  AND is_multi_seller = 0
GROUP BY seller_id, seller_state
HAVING COUNT(*) >= 20
ORDER BY breach_rate_pct DESC
LIMIT 10;


-- ── Q7: Breach Rate by Order Value Tier ─────────────────────
-- Business question: Do higher value orders get better SLA performance?
-- Finding: Counterintuitive — premium orders (R$500+) breach MOST at 8.09%.

SELECT
    CASE
        WHEN total_price < 50   THEN '1. Low (<R$50)'
        WHEN total_price < 150  THEN '2. Medium (R$50-150)'
        WHEN total_price < 500  THEN '3. High (R$150-500)'
        ELSE                         '4. Premium (R$500+)'
    END                                             AS order_value_tier,
    COUNT(*)                                        AS total_orders,
    SUM(sla_breached)                               AS breached_orders,
    ROUND(AVG(sla_breached) * 100, 2)               AS breach_rate_pct,
    ROUND(AVG(days_vs_sla), 1)                      AS avg_days_vs_sla,
    ROUND(AVG(total_price), 2)                      AS avg_order_value,
    ROUND(AVG(seller_processing_days), 1)           AS avg_seller_processing
FROM orders
WHERE total_price IS NOT NULL
GROUP BY order_value_tier
ORDER BY order_value_tier;


-- ── Q8: Breach Rate by Day of Week ──────────────────────────
-- Business question: Does order day affect SLA performance?
-- Finding: Monday worst (7.44%), Sunday best (6.22%). Gap of 1.22pp — modest.
-- Weekend orders actually perform better than weekday orders overall.

SELECT
    CASE CAST(STRFTIME('%w', order_purchase_timestamp) AS INTEGER)
        WHEN 0 THEN '7. Sunday'
        WHEN 1 THEN '1. Monday'
        WHEN 2 THEN '2. Tuesday'
        WHEN 3 THEN '3. Wednesday'
        WHEN 4 THEN '4. Thursday'
        WHEN 5 THEN '5. Friday'
        WHEN 6 THEN '6. Saturday'
    END                                             AS day_of_week,
    COUNT(*)                                        AS total_orders,
    SUM(sla_breached)                               AS breached_orders,
    ROUND(AVG(sla_breached) * 100, 2)               AS breach_rate_pct,
    ROUND(AVG(days_vs_sla), 1)                      AS avg_days_vs_sla,
    ROUND(AVG(seller_processing_days), 1)           AS avg_seller_processing
FROM orders
GROUP BY day_of_week
ORDER BY day_of_week;