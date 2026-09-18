-- индексы для аналитических запросов

-- последовательность событий пользователя по товару
CREATE INDEX IF NOT EXISTS idx_events_visitor_item_time
ON raw.events (visitor_id, item_id, event_time);

-- фильтрация событий по типу и времени
CREATE INDEX IF NOT EXISTS idx_events_type_time
ON raw.events (event_type, event_time);

-- история взаимодействий с отдельным товаром
CREATE INDEX IF NOT EXISTS idx_events_item_time
ON raw.events (item_id, event_time);

-- поиск событий, относящихся к заказам
CREATE INDEX IF NOT EXISTS idx_events_transaction_id
ON raw.events (transaction_id)
WHERE transaction_id IS NOT NULL;

-- временное присвоение категории товару
CREATE INDEX IF NOT EXISTS idx_history_item_changed_at
ON raw.item_category_history (item_id, changed_at);

-- поиск дочерних категорий
CREATE INDEX IF NOT EXISTS idx_categories_parent_id
ON raw.categories (parent_id);

-- обновление статистики для планировщика PostgreSQL
ANALYZE raw.events;
ANALYZE raw.categories;
ANALYZE raw.item_category_history;