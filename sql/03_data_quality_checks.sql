-- проверка данных после загрузки в PostgreSQL
-- скрипт выполняется в базе ecommerce-analysis

-- отображаем время в UTC
SET TIME ZONE 'UTC';

-- 1. Количество строк
SELECT 'events' AS table_name, COUNT(*) AS rows_count
FROM raw.events

UNION ALL

SELECT 'categories', COUNT(*)
FROM raw.categories

UNION ALL

SELECT 'item_category_history', COUNT(*)
FROM raw.item_category_history

ORDER BY table_name;

-- 2. Основные показатели событий
SELECT COUNT(*) AS events_count, COUNT(DISTINCT visitor_id) AS users_count,
COUNT(DISTINCT item_id) AS items_count, COUNT(DISTINCT transaction_id) AS orders_count,
MIN(event_time) AS first_event, MAX(event_time) AS last_event FROM raw.events;

-- 3. Распределение событий
SELECT event_type, COUNT(*) AS events_count, COUNT(DISTINCT visitor_id) AS users_count,
COUNT(DISTINCT item_id) AS items_count, COUNT(DISTINCT transaction_id) AS orders_count FROM raw.events
GROUP BY event_type
ORDER BY events_count DESC;

-- 4. Проверка transaction_id
SELECT COUNT(*) FILTER (WHERE event_type = 'transaction' AND transaction_id IS NULL)
AS transactions_without_id, COUNT(*) FILTER (WHERE event_type <> 'transaction' AND transaction_id IS NOT NULL)
AS non_transactions_with_id
FROM raw.events;

-- 5. Поиск полных дубликатов событий
SELECT COUNT(*) AS duplicate_groups FROM (
SELECT event_timestamp_ms, visitor_id, event_type, item_id, transaction_id,
COUNT(*) AS rows_in_group FROM raw.events
GROUP BY event_timestamp_ms, visitor_id, event_type, item_id, transaction_id
HAVING COUNT(*) > 1) AS duplicates;

-- 6. Проверка дерева категорий
SELECT COUNT(*) AS categories_count, COUNT(*) FILTER (WHERE parent_id IS NULL)
AS root_categories_count, COUNT(DISTINCT parent_id) AS unique_parent_categories FROM raw.categories;

-- 7. Проверка истории категорий
SELECT COUNT(*) AS history_rows, COUNT(DISTINCT item_id) AS items_with_history,
COUNT(*) FILTER (WHERE category_in_tree = FALSE) AS rows_outside_category_tree,
MIN(changed_at) AS first_change, MAX(changed_at) AS last_change FROM raw.item_category_history;