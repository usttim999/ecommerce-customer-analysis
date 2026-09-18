-- построение таблиц заказов
-- одна строка analytics.orders соответствует одному transaction_id
SET TIME ZONE 'UTC';

-- 1. Проверяем, что один заказ принадлежит одному пользователю
SELECT MAX(users_per_order) AS maximum_users_per_order, COUNT(*) FILTER (WHERE users_per_order > 1) AS orders_with_multiple_users
FROM (SELECT transaction_id, COUNT(DISTINCT visitor_id) AS users_per_order FROM raw.events
WHERE event_type = 'transaction'
GROUP BY transaction_id) AS order_users;

-- 2. Перестраиваем производные таблицы
-- raw-таблицы этот блок не удаляет и не изменяет
BEGIN;

DROP TABLE IF EXISTS analytics.order_items;
DROP TABLE IF EXISTS analytics.orders;

-- 3. Одна строка соответствует одному заказу
CREATE TABLE analytics.orders AS
SELECT transaction_id, MIN(visitor_id) AS visitor_id, MIN(event_time) AS order_time, MAX(event_time) AS order_last_event, COUNT(DISTINCT item_id)::INTEGER AS unique_items, COUNT(*)::INTEGER AS transaction_rows, EXTRACT(EPOCH FROM (MAX(event_time) - MIN(event_time))) / 60.0 AS order_duration_minutes
FROM raw.events
WHERE event_type = 'transaction'
GROUP BY transaction_id;

ALTER TABLE analytics.orders
ADD PRIMARY KEY (transaction_id);

CREATE INDEX idx_orders_visitor_time
ON analytics.orders (visitor_id, order_time);

-- 4. Уникальные пары «заказ–товар»
CREATE TABLE analytics.order_items AS
SELECT DISTINCT transaction_id, item_id
FROM raw.events
WHERE event_type = 'transaction';

ALTER TABLE analytics.order_items
ADD PRIMARY KEY (transaction_id, item_id);

ALTER TABLE analytics.order_items
ADD CONSTRAINT order_items_order_fk
FOREIGN KEY (transaction_id)
REFERENCES analytics.orders (transaction_id);

CREATE INDEX idx_order_items_item_id
ON analytics.order_items (item_id);

COMMIT;

-- 5. Обновляем статистику
ANALYZE analytics.orders;
ANALYZE analytics.order_items;

-- 6. Проверяем результат
SELECT COUNT(*) AS orders_count, COUNT(DISTINCT visitor_id) AS buyers_count, SUM(transaction_rows) AS transaction_rows, SUM(unique_items) AS order_unique_items, MAX(unique_items) AS maximum_unique_items_per_order
FROM analytics.orders;

SELECT COUNT(*) AS unique_order_item_pairs
FROM analytics.order_items;
-- проверка таблицы заказов
SELECT COUNT(*) AS orders_count, COUNT(DISTINCT visitor_id) AS buyers_count, SUM(transaction_rows) AS transaction_rows, SUM(unique_items) AS order_unique_items, MAX(unique_items) AS maximum_unique_items_per_order
FROM analytics.orders;
-- проверка пар «заказ–товар»
SELECT COUNT(*) AS unique_order_item_pairs
FROM analytics.order_items;