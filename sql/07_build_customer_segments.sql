-- сегментация покупателей по частоте и давности заказов
-- представление содержит только пользователей с покупками

CREATE OR REPLACE VIEW analytics.customer_segments AS
SELECT visitor_id, orders_count, first_order, last_order, average_unique_items_per_order,
maximum_unique_items_per_order, purchased_item_pairs, unique_purchased_items, purchase_recency_days,

CASE
    WHEN orders_count = 1 THEN '1 заказ'
    WHEN orders_count BETWEEN 2 AND 3 THEN '2–3 заказа'
    WHEN orders_count BETWEEN 4 AND 6 THEN '4–6 заказов'
    WHEN orders_count >= 7 THEN '7+ заказов'
END AS frequency_group,

CASE
    WHEN purchase_recency_days <= 7 THEN 'До 7 дней'
    WHEN purchase_recency_days <= 30 THEN '8–30 дней'
    WHEN purchase_recency_days <= 60 THEN '31–60 дней'
    ELSE 'Более 60 дней'
END AS recency_group,

CASE
    WHEN orders_count >= 7 AND purchase_recency_days <= 30 THEN 'Сверхактивные'
    WHEN orders_count >= 7 THEN 'Сверхактивные под риском'
    WHEN orders_count BETWEEN 4 AND 6 AND purchase_recency_days <= 30 THEN 'Лояльные'
    WHEN orders_count BETWEEN 4 AND 6 THEN 'Лояльные под риском'
    WHEN orders_count BETWEEN 2 AND 3 AND purchase_recency_days <= 30 THEN 'Активные повторные'
    WHEN orders_count BETWEEN 2 AND 3 THEN 'Повторные под риском'
    WHEN orders_count = 1 AND purchase_recency_days <= 30 THEN 'Недавние разовые'
    WHEN orders_count = 1 THEN 'Неактивные разовые'
END AS customer_segment

FROM analytics.user_metrics
WHERE has_purchase = TRUE;

-- проверка охвата покупателей сегментами
SELECT COUNT(*) AS buyers_count, COUNT(*) FILTER (WHERE customer_segment IS NULL) AS buyers_without_segment
FROM analytics.customer_segments;

-- вклад сегментов в покупателей и заказы
SELECT customer_segment, COUNT(*) AS buyers_count,
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS buyers_share,
SUM(orders_count) AS orders_count,
ROUND(SUM(orders_count) * 100.0 / SUM(SUM(orders_count)) OVER (), 2) AS orders_share,
ROUND(AVG(orders_count), 2) AS average_orders,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY purchase_recency_days) AS median_recency_days
FROM analytics.customer_segments
GROUP BY customer_segment
ORDER BY orders_share DESC;