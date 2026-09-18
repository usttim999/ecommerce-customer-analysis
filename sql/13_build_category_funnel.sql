-- назначение временной категории товарной воронке
-- категория определяется на момент первого просмотра

SET TIME ZONE 'UTC';

BEGIN;

DROP TABLE IF EXISTS analytics.product_funnel_7d_categorized;

CREATE TABLE analytics.product_funnel_7d_categorized AS
WITH item_history_start AS (
SELECT item_id, MIN(changed_at) AS first_category_time
FROM raw.item_category_history
GROUP BY item_id)

SELECT f.visitor_id, f.item_id, f.first_view, f.first_cart, f.first_purchase,
f.reached_cart, f.reached_purchase, f.view_month, f.view_weekday_number,
c.category_id, h.root_category_id,

CASE
WHEN c.category_id IS NULL AND s.item_id IS NULL THEN 'no_history'
WHEN c.category_id IS NULL THEN 'before_first_category'
WHEN c.category_in_tree = FALSE THEN 'outside_tree'
ELSE 'known' END AS category_status

FROM analytics.product_funnel_7d AS f

LEFT JOIN item_history_start AS s ON s.item_id = f.item_id

LEFT JOIN LATERAL (
SELECT i.category_id, i.category_in_tree
FROM raw.item_category_history AS i
WHERE i.item_id = f.item_id AND i.changed_at <= f.first_view
ORDER BY i.changed_at DESC, i.change_timestamp_ms DESC, i.history_id DESC
LIMIT 1) AS c ON TRUE

LEFT JOIN analytics.category_hierarchy AS h ON h.category_id = c.category_id AND c.category_in_tree = TRUE;

ALTER TABLE analytics.product_funnel_7d_categorized
ADD PRIMARY KEY (visitor_id, item_id);

CREATE INDEX idx_categorized_funnel_root_month
ON analytics.product_funnel_7d_categorized (root_category_id, view_month);

CREATE INDEX idx_categorized_funnel_status
ON analytics.product_funnel_7d_categorized (category_status);

COMMIT;

ANALYZE analytics.product_funnel_7d_categorized;

-- воронка по корневым категориям и статусу покрытия
CREATE OR REPLACE VIEW analytics.funnel_by_root_category AS
SELECT root_category_id,

CASE
WHEN category_status = 'known' THEN 'Корневая категория ' || root_category_id
WHEN category_status = 'no_history' THEN 'Нет истории категории'
WHEN category_status = 'before_first_category' THEN 'До первой известной категории'
WHEN category_status = 'outside_tree' THEN 'Категория вне дерева'
END AS root_category,

category_status, COUNT(*) AS viewed_pairs, COUNT(*) FILTER (WHERE reached_cart) AS carted_pairs,
COUNT(*) FILTER (WHERE reached_purchase) AS purchased_pairs,
ROUND(COUNT(*) FILTER (WHERE reached_cart) * 100.0 / COUNT(*), 2) AS view_to_cart_rate,
ROUND(COUNT(*) FILTER (WHERE reached_purchase) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE reached_cart), 0), 2) AS cart_to_purchase_rate,
ROUND(COUNT(*) FILTER (WHERE reached_purchase) * 100.0 / COUNT(*), 2) AS view_to_purchase_rate
FROM analytics.product_funnel_7d_categorized
GROUP BY root_category_id, category_status;

-- число пар не должно измениться после назначения категорий
SELECT COUNT(*) AS rows_count, COUNT(DISTINCT (visitor_id, item_id)) AS unique_pairs
FROM analytics.product_funnel_7d_categorized;

-- покрытие воронки категориями
SELECT category_status, COUNT(*) AS pairs_count,
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pairs_share
FROM analytics.product_funnel_7d_categorized
GROUP BY category_status
ORDER BY pairs_count DESC;

-- показатели корневых категорий
SELECT *
FROM analytics.funnel_by_root_category
ORDER BY viewed_pairs DESC;