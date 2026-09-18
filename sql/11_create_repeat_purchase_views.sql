-- возврат покупателей ко второму заказу
-- основной показатель исключает транзакции в течение часа после первого заказа

SET TIME ZONE 'UTC';

CREATE OR REPLACE VIEW analytics.repeat_purchase_metrics AS
WITH analysis_period AS (SELECT MAX(order_time) AS analysis_end
FROM analytics.orders),

first_orders AS (SELECT visitor_id, MIN(order_time) AS first_order
FROM analytics.orders
GROUP BY visitor_id),

first_valid_returns AS (SELECT f.visitor_id, MIN(o.order_time) AS return_time
FROM first_orders AS f
JOIN analytics.orders AS o ON o.visitor_id = f.visitor_id AND o.order_time >= f.first_order + INTERVAL '1 hour'
GROUP BY f.visitor_id),

windows AS (SELECT *
FROM (VALUES (7), (30), (60), (90)) AS w(window_days))

SELECT w.window_days, a.analysis_end - w.window_days * INTERVAL '1 day' AS eligibility_cutoff,
COUNT(*) AS eligible_buyers,
COUNT(*) FILTER (WHERE r.return_time <= f.first_order + w.window_days * INTERVAL '1 day') AS returned_buyers,
ROUND(COUNT(*) FILTER (WHERE r.return_time <= f.first_order + w.window_days * INTERVAL '1 day') * 100.0 / COUNT(*), 2) AS adjusted_repeat_rate
FROM first_orders AS f
CROSS JOIN analysis_period AS a
CROSS JOIN windows AS w
LEFT JOIN first_valid_returns AS r ON r.visitor_id = f.visitor_id
WHERE f.first_order <= a.analysis_end - w.window_days * INTERVAL '1 day'
GROUP BY w.window_days, a.analysis_end;

-- чувствительность результата к ограничению 0, 1 и 24 часа
CREATE OR REPLACE VIEW analytics.repeat_purchase_sensitivity AS
WITH analysis_period AS (SELECT MAX(order_time) AS analysis_end
FROM analytics.orders),

first_order_rows AS (SELECT DISTINCT ON (visitor_id) visitor_id, transaction_id AS first_transaction_id, order_time AS first_order
FROM analytics.orders
ORDER BY visitor_id, order_time, transaction_id),

windows AS (SELECT *
FROM (VALUES (7), (30), (60), (90)) AS w(window_days)),

cooldowns AS (SELECT *
FROM (VALUES (0), (1), (24)) AS c(cooldown_hours)),

first_returns AS (SELECT f.visitor_id, c.cooldown_hours, MIN(o.order_time) AS return_time
FROM first_order_rows AS f
CROSS JOIN cooldowns AS c
LEFT JOIN analytics.orders AS o ON o.visitor_id = f.visitor_id
AND o.transaction_id <> f.first_transaction_id
AND o.order_time >= f.first_order + c.cooldown_hours * INTERVAL '1 hour'
GROUP BY f.visitor_id, c.cooldown_hours),

eligible_buyers AS (SELECT f.visitor_id, f.first_order
FROM first_order_rows AS f
CROSS JOIN analysis_period AS a
WHERE f.first_order <= a.analysis_end - INTERVAL '90 days')

SELECT c.cooldown_hours, w.window_days, COUNT(*) AS eligible_buyers,
COUNT(*) FILTER (WHERE r.return_time <= e.first_order + w.window_days * INTERVAL '1 day') AS returned_buyers,
ROUND(COUNT(*) FILTER (WHERE r.return_time <= e.first_order + w.window_days * INTERVAL '1 day') * 100.0 / COUNT(*), 2) AS repeat_rate
FROM eligible_buyers AS e
CROSS JOIN cooldowns AS c
CROSS JOIN windows AS w
LEFT JOIN first_returns AS r ON r.visitor_id = e.visitor_id
AND r.cooldown_hours = c.cooldown_hours
GROUP BY c.cooldown_hours, w.window_days;

-- возврат на максимально доступной аудитории
SELECT *
FROM analytics.repeat_purchase_metrics
ORDER BY window_days;

-- сравнение разных ограничений на общей 90-дневной аудитории
SELECT cooldown_hours, MAX(repeat_rate) FILTER (WHERE window_days = 7) AS days_7,
MAX(repeat_rate) FILTER (WHERE window_days = 30) AS days_30,
MAX(repeat_rate) FILTER (WHERE window_days = 60) AS days_60,
MAX(repeat_rate) FILTER (WHERE window_days = 90) AS days_90
FROM analytics.repeat_purchase_sensitivity
GROUP BY cooldown_hours
ORDER BY cooldown_hours;