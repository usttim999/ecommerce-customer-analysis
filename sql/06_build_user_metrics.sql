-- построение пользовательской аналитической таблицы
-- одна строка соответствует одному visitor_id
SET TIME ZONE 'UTC';

BEGIN;

DROP TABLE IF EXISTS analytics.user_metrics;

CREATE TABLE analytics.user_metrics AS
WITH analysis_period AS (SELECT MAX(event_time)::DATE AS analysis_date FROM raw.events),

event_metrics AS (SELECT visitor_id, MIN(event_time) AS first_event, MAX(event_time) AS last_event,
COUNT(*) AS total_events, COUNT(DISTINCT event_time::DATE) AS active_days,
COUNT(DISTINCT item_id) AS unique_interacted_items,
COUNT(*) FILTER (WHERE event_type = 'view') AS view_events,
COUNT(*) FILTER (WHERE event_type = 'addtocart') AS cart_events,
COUNT(*) FILTER (WHERE event_type = 'transaction') AS transaction_events
FROM raw.events
GROUP BY visitor_id),

order_metrics AS (SELECT visitor_id, COUNT(*) AS orders_count, MIN(order_time) AS first_order,
MAX(order_time) AS last_order, AVG(unique_items) AS average_unique_items_per_order,
MAX(unique_items) AS maximum_unique_items_per_order, SUM(unique_items) AS purchased_item_pairs
FROM analytics.orders
GROUP BY visitor_id),


purchased_items AS (SELECT o.visitor_id, COUNT(DISTINCT oi.item_id) AS unique_purchased_items
FROM analytics.orders AS o JOIN analytics.order_items AS oi ON oi.transaction_id = o.transaction_id
GROUP BY o.visitor_id)

SELECT e.visitor_id, e.first_event, e.last_event, e.total_events, e.active_days,
e.unique_interacted_items, e.view_events, e.cart_events, e.transaction_events,
COALESCE(o.orders_count, 0) AS orders_count, o.first_order, o.last_order,
COALESCE(o.average_unique_items_per_order, 0) AS average_unique_items_per_order,
COALESCE(o.maximum_unique_items_per_order, 0) AS maximum_unique_items_per_order,
COALESCE(o.purchased_item_pairs, 0) AS purchased_item_pairs,
COALESCE(p.unique_purchased_items, 0) AS unique_purchased_items,
o.visitor_id IS NOT NULL AS has_purchase,
a.analysis_date - e.last_event::DATE AS activity_recency_days,
CASE WHEN o.last_order IS NOT NULL THEN a.analysis_date - o.last_order::DATE END AS purchase_recency_days,
e.last_event::DATE - e.first_event::DATE AS observed_lifetime_days
FROM event_metrics AS e
CROSS JOIN analysis_period AS a
LEFT JOIN order_metrics AS o ON o.visitor_id = e.visitor_id
LEFT JOIN purchased_items AS p ON p.visitor_id = e.visitor_id;

ALTER TABLE analytics.user_metrics
ADD PRIMARY KEY (visitor_id);

CREATE INDEX idx_user_metrics_orders_count ON analytics.user_metrics (orders_count);

CREATE INDEX idx_user_metrics_purchase_recency ON analytics.user_metrics (purchase_recency_days)
WHERE has_purchase = TRUE;

COMMIT;

ANALYZE analytics.user_metrics;

-- проверка пользовательской таблицы
SELECT COUNT(*) AS users_count, COUNT(*) FILTER (WHERE has_purchase = TRUE) AS buyers_count,
SUM(orders_count) AS orders_count, SUM(purchased_item_pairs) AS purchased_item_pairs,
MAX(orders_count) AS maximum_orders_per_buyer
FROM analytics.user_metrics;

-- проверка пользователей без покупок
SELECT COUNT(*) AS invalid_non_buyers
FROM analytics.user_metrics
WHERE has_purchase = FALSE AND (orders_count <> 0 OR first_order IS NOT NULL OR last_order IS NOT NULL);

