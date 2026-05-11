/*
================================================================================
ПРОЕКТ: Экономика клиента (LTV и Retention анализ)
ОПИСАНИЕ: Расчет пожизненной ценности клиента в разрезе географии 
          и анализ времени до повторной покупки.
================================================================================
*/

--------------------------------------------------------------------------------
-- 1. СРЕДНИЙ LTV ПО ШТАТАМ
-- Цель: Выявить регионы с наиболее ценными клиентами для приоритизации маркетинга.
--------------------------------------------------------------------------------

-- Считаем LTV для каждого клиента
WITH ltv_data AS  (
    SELECT 
        c.customer_unique_id,
        c.customer_state,
        SUM(p.payment_value) as total_sum -- Сколько всего потрачено клиентом
    FROM customers c
    JOIN orders o USING(customer_id)
    JOIN order_payments p USING(order_id)
    WHERE o.order_status = 'delivered' -- Считаем только реально полученные деньги
    GROUP BY 1, 2
)
-- Считаем среднее LTV по штатам
SELECT 
	customer_state,
	ROUND(AVG(total_sum), 2) AS avg_ltv, -- Среднее LTV по штатам
	COUNT(customer_unique_id) AS total_customers -- Сколько всего покупателей
FROM ltv_data
GROUP BY 1
ORDER BY avg_ltv DESC


--------------------------------------------------------------------------------
-- 2. АНАЛИЗ ПОВТОРНЫХ ПОКУПОК (Retention Time)
-- Цель: Понять, через какой период времени клиенты возвращаются за вторым заказом.
--------------------------------------------------------------------------------

WITH orders_sequence AS (
    -- Соединяем таблицы и подтягиваем дату следующего заказа для каждой строки
    SELECT 
        c.customer_unique_id,
        o.order_purchase_timestamp AS current_order_date,
        -- LEAD берет дату следующего по счету заказа этого же клиента
        LEAD(o.order_purchase_timestamp) OVER (
            PARTITION BY c.customer_unique_id 
            ORDER BY o.order_purchase_timestamp
        ) AS next_order_date,
        -- Присваиваем порядковый номер каждому заказу клиента
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id 
            ORDER BY o.order_purchase_timestamp
        ) AS order_num
    FROM orders o
    JOIN customers c USING(customer_id)
)
-- Выбираем только тех, кто сделал хотя бы два заказа, и считаем разницу
SELECT 
    customer_unique_id,
    current_order_date AS first_order,
    next_order_date AS second_order,
    -- Вычитаем даты через JULIANDAY, чтобы получить разницу в днях
    ROUND(JULIANDAY(next_order_date) - JULIANDAY(current_order_date), 2) AS days_diff
FROM orders_sequence
WHERE order_num = 1 -- Нам нужна разница именно между 1-м и 2-м заказом
  AND next_order_date IS NOT NULL -- Отсекаем тех, кто купил только один раз
ORDER BY days_diff DESC;

-- ИНСАЙТ: Среднее время возврата помогает настроить ретаргетинг и email-рассылки.
