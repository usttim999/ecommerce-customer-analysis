-- временные интервалы категорий товаров
-- интервал включает valid_from, но не включает valid_to

CREATE OR REPLACE VIEW analytics.item_category_intervals AS
SELECT item_id, category_id, category_in_tree, changed_at AS valid_from,
LEAD(changed_at) OVER (PARTITION BY item_id ORDER BY changed_at,
change_timestamp_ms, history_id) AS valid_to
FROM raw.item_category_history;

-- соответствие каждой категории её корневой категории
BEGIN;

DROP TABLE IF EXISTS analytics.category_hierarchy;

CREATE TABLE analytics.category_hierarchy AS
WITH RECURSIVE category_paths AS (SELECT category_id, category_id AS ancestor_id, parent_id, 0 AS depth
FROM raw.categories

UNION ALL

SELECT p.category_id, c.category_id AS ancestor_id, c.parent_id, p.depth + 1 AS depth
FROM category_paths AS p
JOIN raw.categories AS c ON c.category_id = p.parent_id)

SELECT category_id, ancestor_id AS root_category_id, depth
FROM category_paths
WHERE parent_id IS NULL;

ALTER TABLE analytics.category_hierarchy
ADD PRIMARY KEY (category_id);

CREATE INDEX idx_category_hierarchy_root
ON analytics.category_hierarchy (root_category_id);

COMMIT;

ANALYZE analytics.category_hierarchy;

-- проверка временных интервалов категорий
SELECT COUNT(*) AS intervals_count, COUNT(DISTINCT item_id) AS items_count,
COUNT(*) FILTER (WHERE valid_to IS NULL) AS open_intervals,
COUNT(*) FILTER (WHERE category_in_tree = FALSE) AS intervals_outside_tree
FROM analytics.item_category_intervals;

-- проверка соответствия корневым категориям
SELECT COUNT(*) AS categories_count, COUNT(DISTINCT root_category_id) AS root_categories_count,
MAX(depth) AS maximum_depth
FROM analytics.category_hierarchy;

-- категорий без найденного корня быть не должно
SELECT COUNT(*) AS categories_without_root
FROM raw.categories AS c
LEFT JOIN analytics.category_hierarchy AS h ON h.category_id = c.category_id
WHERE h.category_id IS NULL;