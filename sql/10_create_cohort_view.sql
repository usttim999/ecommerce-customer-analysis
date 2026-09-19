-- когортное удержание покупателей
-- когорта определяется месяцем первого наблюдаемого заказа
-- используются только полностью завершённые календарные месяцы

SET TIME ZONE 'UTC';

CREATE OR REPLACE VIEW analytics.cohort_retention AS
WITH buyer_months AS (SELECT DISTINCT visitor_id, DATE_TRUNC('month', order_time AT TIME ZONE 'UTC')::DATE AS order_month
FROM analytics.orders),

buyer_cohorts AS (SELECT visitor_id, MIN(order_month) AS cohort_month
FROM buyer_months
GROUP BY visitor_id),

cohort_activity AS (SELECT c.cohort_month, m.order_month,
((EXTRACT(YEAR FROM m.order_month) - EXTRACT(YEAR FROM c.cohort_month)) * 12 + EXTRACT(MONTH FROM m.order_month) - EXTRACT(MONTH FROM c.cohort_month))::INTEGER AS cohort_index,
COUNT(DISTINCT m.visitor_id) AS active_buyers
FROM buyer_months AS m
JOIN buyer_cohorts AS c ON c.visitor_id = m.visitor_id
GROUP BY c.cohort_month, m.order_month),

cohort_sizes AS (SELECT cohort_month, COUNT(*) AS cohort_size
FROM buyer_cohorts
GROUP BY cohort_month),

last_complete_period AS (SELECT (DATE_TRUNC('month', MAX(order_time) AT TIME ZONE 'UTC') - INTERVAL '1 month')::DATE AS last_complete_month
FROM analytics.orders),

available_periods AS (SELECT s.cohort_month, s.cohort_size,
p.cohort_index, (s.cohort_month + p.cohort_index * INTERVAL '1 month')::DATE AS activity_month
FROM cohort_sizes AS s
CROSS JOIN last_complete_period AS l
CROSS JOIN LATERAL GENERATE_SERIES(0, ((EXTRACT(YEAR FROM l.last_complete_month) - EXTRACT(YEAR FROM s.cohort_month)) * 12 + EXTRACT(MONTH FROM l.last_complete_month) - EXTRACT(MONTH FROM s.cohort_month))::INTEGER) AS p(cohort_index)
WHERE s.cohort_month <= l.last_complete_month)

SELECT p.cohort_month, p.cohort_index, 'M+' || p.cohort_index AS cohort_period, p.activity_month,
COALESCE(a.active_buyers, 0) AS active_buyers, p.cohort_size,
ROUND(COALESCE(a.active_buyers, 0) * 100.0 / p.cohort_size, 2) AS retention_rate
FROM available_periods AS p
LEFT JOIN cohort_activity AS a ON a.cohort_month = p.cohort_month
AND a.cohort_index = p.cohort_index;

-- когортное удержание
SELECT *
FROM analytics.cohort_retention
ORDER BY cohort_month, cohort_index;

-- матрица когортного удержания
SELECT cohort_month, MAX(retention_rate) FILTER (WHERE cohort_index = 0) AS m0,
MAX(retention_rate) FILTER (WHERE cohort_index = 1) AS m1,
MAX(retention_rate) FILTER (WHERE cohort_index = 2) AS m2,
MAX(retention_rate) FILTER (WHERE cohort_index = 3) AS m3
FROM analytics.cohort_retention
GROUP BY cohort_month
ORDER BY cohort_month;