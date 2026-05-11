/*
================================================================================
ПРОЕКТ: Анализ эффективности логистики маркетплейса Olist
ОПИСАНИЕ: Исследование времени доставки, расчет процента опозданий 
и оценка влияния задержек на лояльность клиентов.

================================================================================
*/

--------------------------------------------------------------------------------
-- 1. СРЕДНЕЕ ВРЕМЯ ДОСТАВКИ ПО ШТАТАМ
-- Цель: Выявить регионы с самой медленной логистикой для оптимизации цепочек поставок.
--------------------------------------------------------------------------------

SELECT 
    customer_state, --Название штата
    ROUND(AVG(JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_purchase_timestamp )), 2) AS AVG_time_del --Среднее время доставки по штату
FROM customers c 
JOIN orders o USING(customer_id)
WHERE o.order_delivered_customer_date IS NOT NULL 
    AND o.order_status = 'delivered' --Отбираем только доставленные заказы
GROUP BY c.customer_state --Группируем по штатам
ORDER BY 2 DESC --Сортируем среднее время по убыванию
LIMIT 5; --Рассматриваем 5 штатов с самой долгой средней доставкой


--------------------------------------------------------------------------------
-- 2. ПРОЦЕНТ ДОСТАВОК С ЗАДЕРЖКОЙ (On-Time Delivery Rate)
-- Цель: Посчитать долю заказов, доставленных позже обещанного срока (Estimated Date).
-- Мы используем фильтр HAVING > 100, чтобы исключить штаты с малым количеством данных.
--------------------------------------------------------------------------------

SELECT 
    customer_state, --Название штата
    COUNT(customer_id) AS amount_of_orders, --Общее количество заказов по штату
    SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS deliver_delay, -- Количество доставок с задержкой по штату
    ROUND((SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) * 1.0) / COUNT(customer_id) * 100.0, 2) AS percentage_of_delays --Процент доставок с задержкой по штату
FROM customers c 
JOIN orders o USING(customer_id)
WHERE o.order_delivered_customer_date IS NOT NULL 
    AND o.order_status = 'delivered' --Отбираем только доставленные заказы
GROUP BY c.customer_state --Группируем по штатам
HAVING COUNT(customer_id)>100 --Отбираем только штаты в которых сделано более 100 заказов, чтобы отсечь штаты с непоказательной статистикой
ORDER BY 4 DESC;


--------------------------------------------------------------------------------
-- 3. ВЛИЯНИЕ ЛОГИСТИКИ НА ОЦЕНКУ ЗАКАЗА (CSAT Analysis)
-- Цель: Измерить корреляцию между задержкой доставки и средним рейтингом отзыва.
--------------------------------------------------------------------------------

SELECT 
    CASE 
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Late'
        ELSE 'On Time'
    END AS delivery_status, -- Разделяем заказы на две группы "Досталвленные вовремя" и "С опозданием"
	ROUND(AVG(r.review_score), 2) AS avg_review, --Средняя оценка клиентов по группе
	COUNT(r.review_score) AS amount_review, -- Всего оценок
	ROUND(SUM(CASE 
	    WHEN r.review_score=1 THEN 1 
	    ELSE 0 
	END) * 1.0 / COUNT(r.review_score) * 100.0, 2) AS percentage_of_review_1 -- Процент оценок "1"
FROM orders o
JOIN order_reviews r USING(order_id)
WHERE order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL--Отбираем только доставленные заказы
GROUP BY delivery_status -- Группируем по статусу доставки
