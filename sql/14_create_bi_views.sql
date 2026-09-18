-- итоговые показатели для главной страницы дашборда
CREATE OR REPLACE VIEW analytics.bi_kpi_overview AS
WITH event_period AS (SELECT MIN(event_time) AS first_event,
MAX(event_time) AS last_event
FROM raw.events),

user_stats AS (SELECT COUNT(*) AS users_count
FROM analytics.user_metrics),

buyer_orders AS (SELECT visitor_id, COUNT(*) AS orders_count
FROM analytics.orders
GROUP BY visitor_id),

order_stats AS (SELECT COUNT(*) AS buyers_count, SUM(orders_count) AS orders_count,
COUNT(*) FILTER (WHERE orders_count > 1) AS repeat_buyers
FROM buyer_orders),

repeat_30d AS (SELECT MAX(adjusted_repeat_rate) FILTER (WHERE window_days = 30) AS repeat_purchase_30d
FROM analytics.repeat_purchase_metrics)

SELECT e.first_event, e.last_event, u.users_count, o.buyers_count, o.orders_count,
o.repeat_buyers, ROUND(100.0 * o.repeat_buyers / NULLIF(o.buyers_count, 0), 2) AS repeat_buyers_share,
r.repeat_purchase_30d, f.viewed_pairs, f.carted_pairs, f.purchased_pairs, f.view_to_cart_rate,
f.cart_to_purchase_rate, f.view_to_purchase_rate, f.completed_users
FROM event_period e
CROSS JOIN user_stats u
CROSS JOIN order_stats o
CROSS JOIN repeat_30d r
CROSS JOIN analytics.funnel_overall f;

-- категории, подготовленные для сравнения в Power BI
CREATE OR REPLACE VIEW analytics.bi_category_funnel AS
SELECT root_category_id, root_category, category_status, viewed_pairs, carted_pairs, purchased_pairs,
view_to_cart_rate, cart_to_purchase_rate, view_to_purchase_rate, viewed_pairs >= 1000 AS sufficient_volume,
CASE
WHEN viewed_pairs >= 10000 THEN 'large'
WHEN viewed_pairs >= 1000 THEN 'medium'
ELSE 'small' END AS sample_group
FROM analytics.funnel_by_root_category;

--проверка
SELECT *
FROM analytics.bi_kpi_overview;

--проверка
SELECT sample_group,
       COUNT(*) AS categories_count,
       SUM(viewed_pairs) AS viewed_pairs
FROM analytics.bi_category_funnel
GROUP BY sample_group
ORDER BY MIN(viewed_pairs) DESC;
