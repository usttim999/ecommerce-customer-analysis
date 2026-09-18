-- аналитические представления семидневной товарной воронки
-- представления предназначены для SQL-анализа и Power BI

-- общая воронка
CREATE OR REPLACE VIEW analytics.funnel_overall AS
SELECT COUNT(*) AS viewed_pairs, COUNT(*) FILTER (WHERE reached_cart) AS carted_pairs,
COUNT(*) FILTER (WHERE reached_purchase) AS purchased_pairs,
ROUND(COUNT(*) FILTER (WHERE reached_cart) * 100.0 / COUNT(*), 2) AS view_to_cart_rate,
ROUND(COUNT(*) FILTER (WHERE reached_purchase) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE reached_cart), 0), 2) AS cart_to_purchase_rate,
ROUND(COUNT(*) FILTER (WHERE reached_purchase) * 100.0 / COUNT(*), 2) AS view_to_purchase_rate,
COUNT(DISTINCT visitor_id) FILTER (WHERE reached_purchase) AS completed_users
FROM analytics.product_funnel_7d;

-- воронка по месяцу первого просмотра
CREATE OR REPLACE VIEW analytics.funnel_by_month AS
SELECT view_month, COUNT(*) AS viewed_pairs, COUNT(*) FILTER (WHERE reached_cart) AS carted_pairs,
COUNT(*) FILTER (WHERE reached_purchase) AS purchased_pairs,
ROUND(COUNT(*) FILTER (WHERE reached_cart) * 100.0 / COUNT(*), 2) AS view_to_cart_rate,
ROUND(COUNT(*) FILTER (WHERE reached_purchase) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE reached_cart), 0), 2) AS cart_to_purchase_rate,
ROUND(COUNT(*) FILTER (WHERE reached_purchase) * 100.0 / COUNT(*), 2) AS view_to_purchase_rate
FROM analytics.product_funnel_7d
GROUP BY view_month;

-- воронка по дню недели первого просмотра
CREATE OR REPLACE VIEW analytics.funnel_by_weekday AS
SELECT view_weekday_number,

CASE view_weekday_number
WHEN 1 THEN 'Понедельник'
WHEN 2 THEN 'Вторник'
WHEN 3 THEN 'Среда'
WHEN 4 THEN 'Четверг'
WHEN 5 THEN 'Пятница'
WHEN 6 THEN 'Суббота'
WHEN 7 THEN 'Воскресенье'
END AS weekday,

COUNT(*) AS viewed_pairs, COUNT(*) FILTER (WHERE reached_cart) AS carted_pairs,
COUNT(*) FILTER (WHERE reached_purchase) AS purchased_pairs,
ROUND(COUNT(*) FILTER (WHERE reached_cart) * 100.0 / COUNT(*), 2) AS view_to_cart_rate,
ROUND(COUNT(*) FILTER (WHERE reached_purchase) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE reached_cart), 0), 2) AS cart_to_purchase_rate,
ROUND(COUNT(*) FILTER (WHERE reached_purchase) * 100.0 / COUNT(*), 2) AS view_to_purchase_rate
FROM analytics.product_funnel_7d
GROUP BY view_weekday_number;

-- месячная воронка
SELECT *
FROM analytics.funnel_by_month
ORDER BY view_month;

-- воронка по дням недели
SELECT *
FROM analytics.funnel_by_weekday
ORDER BY view_weekday_number;