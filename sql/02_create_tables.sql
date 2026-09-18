-- Создание исходных таблиц проекта
-- Скрипт выполняется в базе данных ecommerce_analysis

-- События пользователей
CREATE TABLE IF NOT EXISTS raw.events (
    event_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_timestamp_ms BIGINT NOT NULL,
    visitor_id BIGINT NOT NULL,
    event_type VARCHAR(20) NOT NULL,
    item_id BIGINT NOT NULL,
    transaction_id BIGINT,
    event_time TIMESTAMPTZ NOT NULL,

    CONSTRAINT events_event_type_check
        CHECK (event_type IN ('view', 'addtocart', 'transaction')));

COMMENT ON TABLE raw.events IS
'Cleaned user events: views, cart additions and transactions';

COMMENT ON COLUMN raw.events.event_timestamp_ms IS
'Original Unix timestamp in milliseconds';

COMMENT ON COLUMN raw.events.transaction_id IS
'Transaction identifier; NULL for non-transaction events';

-- Дерево категорий
CREATE TABLE IF NOT EXISTS raw.categories (
    category_id INTEGER PRIMARY KEY,
    parent_id INTEGER);

COMMENT ON TABLE raw.categories IS
    'Product category hierarchy';

COMMENT ON COLUMN raw.categories.parent_id IS
    'Parent category; NULL for root categories';

-- История категорий товаров
CREATE TABLE IF NOT EXISTS raw.item_category_history (
    history_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    change_timestamp_ms BIGINT NOT NULL,
    item_id BIGINT NOT NULL,
    category_id INTEGER NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL,
    category_in_tree BOOLEAN NOT NULL);

COMMENT ON TABLE raw.item_category_history IS
'History of item category assignments after temporal compression';

COMMENT ON COLUMN raw.item_category_history.category_in_tree IS
'Whether the category exists in the cleaned category tree';