-- семидневная товарная воронка
-- одна строка соответствует одной паре visitor_id + item_id
SET TIME ZONE 'UTC';

BEGIN;

DROP TABLE IF EXISTS analytics.product_funnel_7d;

CREATE TABLE analytics.product_funnel_7d AS
WITH analysis_period AS (SELECT MAX(event_time) AS analysis_end
FROM raw.events),

first_views AS (SELECT visitor_id, item_id, MIN(event_time) AS first_view
FROM raw.events
WHERE event_type = 'view'
GROUP BY visitor_id, item_id),

eligible_views AS (SELECT v.visitor_id, v.item_id, v.first_view
FROM first_views AS v
CROSS JOIN analysis_period AS a
WHERE v.first_view <= a.analysis_end - INTERVAL '7 days'),

cart_steps AS (SELECT v.visitor_id, v.item_id, v.first_view, MIN(c.event_time) AS first_cart
FROM eligible_views AS v
LEFT JOIN raw.events AS c ON c.visitor_id = v.visitor_id AND c.item_id = v.item_id
AND c.event_type = 'addtocart' AND c.event_time >= v.first_view
AND c.event_time <= v.first_view + INTERVAL '7 days'
GROUP BY v.visitor_id, v.item_id, v.first_view),

purchase_events AS (SELECT o.visitor_id, oi.item_id, o.order_time AS purchase_time
FROM analytics.orders AS o
JOIN analytics.order_items AS oi ON oi.transaction_id = o.transaction_id),

funnel_times AS (SELECT c.visitor_id, c.item_id, c.first_view, c.first_cart,
MIN(p.purchase_time) AS first_purchase
FROM cart_steps AS c
LEFT JOIN purchase_events AS p ON p.visitor_id = c.visitor_id AND p.item_id = c.item_id
AND p.purchase_time >= c.first_cart AND p.purchase_time <= c.first_view + INTERVAL '7 days'
GROUP BY c.visitor_id, c.item_id, c.first_view, c.first_cart)

SELECT visitor_id, item_id, first_view, first_cart, first_purchase,
first_cart IS NOT NULL AS reached_cart, first_purchase IS NOT NULL AS reached_purchase,
DATE_TRUNC('month', first_view)::DATE AS view_month,
EXTRACT(ISODOW FROM first_view)::SMALLINT AS view_weekday_number
FROM funnel_times;

ALTER TABLE analytics.product_funnel_7d
ADD PRIMARY KEY (visitor_id, item_id);

CREATE INDEX idx_funnel_view_month
ON analytics.product_funnel_7d (view_month);

CREATE INDEX idx_funnel_view_weekday
ON analytics.product_funnel_7d (view_weekday_number);

COMMIT;

ANALYZE analytics.product_funnel_7d;

-- итоговая семидневная воронка
SELECT COUNT(*) AS viewed_pairs, COUNT(*) FILTER (WHERE reached_cart) AS carted_pairs,
COUNT(*) FILTER (WHERE reached_purchase) AS purchased_pairs,
ROUND(COUNT(*) FILTER (WHERE reached_cart) * 100.0 / COUNT(*), 2) AS view_to_cart_rate,
ROUND(COUNT(*) FILTER (WHERE reached_purchase) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE reached_cart), 0), 2) AS cart_to_purchase_rate,
ROUND(COUNT(*) FILTER (WHERE reached_purchase) * 100.0 / COUNT(*), 2) AS view_to_purchase_rate,
COUNT(DISTINCT visitor_id) FILTER (WHERE reached_purchase) AS completed_users
FROM analytics.product_funnel_7d;

-- временных нарушений быть не должно
SELECT COUNT(*) AS invalid_funnel_rows
FROM analytics.product_funnel_7d
WHERE first_cart < first_view OR first_purchase < first_cart OR first_cart > first_view + INTERVAL '7 days'
OR first_purchase > first_view + INTERVAL '7 days';