-- ============================================================================
-- ТехноМир — решения к practice/tasks.md
-- Сначала попробуйте решить сами! Ваше решение может отличаться — главное,
-- чтобы совпал результат (число строк и ключевые значения из tasks.md).
--
-- Выручка во всех задачах = сумма позиций (quantity * unit_price) по заказам
-- со статусом paid, shipped или delivered. «Сегодня» = 2026-10-10.
-- ============================================================================


-- ============================================================================
-- Уровень 1. SELECT, WHERE, ORDER BY
-- ============================================================================

-- Задача 1. Товары, которые заканчиваются (осталось от 1 до 4 штук)
SELECT name, model, stock
FROM products
WHERE stock BETWEEN 1 AND 4
ORDER BY stock, name;

-- Задача 2. Покупатель по фрагменту телефона «456»
SELECT id, name, phone, email
FROM customers
WHERE phone LIKE '%456%';

-- Задача 3. Телевизоры дороже 50 000
SELECT p.name, p.model, p.price
FROM products p
JOIN categories c ON c.id = p.category_id
WHERE c.name = 'Телевизоры' AND p.price > 50000
ORDER BY p.price DESC;

-- Задача 4. Покупатели, зарегистрированные в сентябре–октябре 2026
SELECT id, name, email, created_at
FROM customers
WHERE created_at >= '2026-09-01' AND created_at < '2026-11-01'
ORDER BY created_at;

-- Задача 5. Заказы без адреса доставки
SELECT id, customer_id, status, created_at
FROM orders
WHERE address_id IS NULL;

-- Задача 6. Самые энергоэффективные товары мощнее 1 000 Вт
SELECT name, model, power_watt, energy_class
FROM products
WHERE energy_class IN ('A++', 'A+') AND power_watt > 1000
ORDER BY power_watt DESC;


-- ============================================================================
-- Уровень 2. JOIN, GROUP BY, агрегаты
-- ============================================================================

-- Задача 7. Выручка по брендам
SELECT b.name AS brand, SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi
JOIN orders   o ON o.id = oi.order_id
JOIN products p ON p.id = oi.product_id
JOIN brands   b ON b.id = p.brand_id
WHERE o.status IN ('paid', 'shipped', 'delivered')
GROUP BY b.name
ORDER BY revenue DESC;

-- Задача 8. Сколько заказов в каждом статусе и на какую сумму
SELECT status, COUNT(*) AS orders_cnt, SUM(total) AS total_sum
FROM orders
GROUP BY status
ORDER BY orders_cnt DESC;

-- Задача 9. Топ-5 городов по числу заказов
SELECT a.city, COUNT(*) AS orders_cnt
FROM orders o
JOIN addresses a ON a.id = o.address_id
GROUP BY a.city
ORDER BY orders_cnt DESC, a.city
LIMIT 5;

-- Задача 10. «Мёртвый» склад: товары в наличии, которые ни разу не заказывали,
-- и сколько денег в них заморожено
SELECT p.name, p.model, p.stock, p.price, p.stock * p.price AS frozen_money
FROM products p
WHERE p.stock > 0
  AND NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.product_id = p.id)
ORDER BY frozen_money DESC;

-- Задача 11. Наценка: цена продажи против самой дешёвой цены закупки
SELECT p.name,
       p.model,
       p.price,
       MIN(ps.supply_price)                                        AS best_supply_price,
       ROUND((p.price - MIN(ps.supply_price)) / p.price * 100, 1) AS margin_pct
FROM products p
JOIN product_suppliers ps ON ps.product_id = p.id
GROUP BY p.id, p.name, p.model, p.price
ORDER BY margin_pct DESC;

-- Задача 12. Средний чек по месяцам
SELECT DATE_TRUNC('month', created_at)::DATE AS month,
       COUNT(*)                               AS orders_cnt,
       ROUND(AVG(total), 2)                   AS avg_check
FROM orders
WHERE status IN ('paid', 'shipped', 'delivered')
GROUP BY month
ORDER BY month;

-- Задача 13. Покупатели, которые брали технику и Samsung, и LG
SELECT c.id, c.name
FROM customers c
JOIN orders      o  ON o.customer_id = c.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products    p  ON p.id = oi.product_id
JOIN brands      b  ON b.id = p.brand_id
WHERE b.name IN ('Samsung', 'LG')
GROUP BY c.id, c.name
HAVING COUNT(DISTINCT b.name) = 2;


-- ============================================================================
-- Уровень 3. Проверка данных (QA)
-- Запросы, которые в идеальной базе возвращают 0 строк.
-- ============================================================================

-- Задача 14. Сумма платежей не совпадает с суммой заказа
SELECT o.id, o.total, SUM(p.amount) AS paid
FROM orders o
JOIN payments p ON p.order_id = o.id
GROUP BY o.id, o.total
HAVING SUM(p.amount) <> o.total;

-- Задача 15. Заказ считается оплаченным, а платежа нет — и наоборот
SELECT o.id, o.status, COUNT(p.id) AS payments_cnt
FROM orders o
LEFT JOIN payments p ON p.order_id = o.id
GROUP BY o.id, o.status
HAVING (o.status IN ('paid', 'shipped', 'delivered') AND COUNT(p.id) = 0)
    OR (o.status IN ('new', 'cancelled')             AND COUNT(p.id) > 0);

-- Задача 16. Отзывы на товар, который покупатель не получал
SELECT r.id, c.name AS customer, p.name AS product, r.rating
FROM reviews r
JOIN customers c ON c.id = r.customer_id
JOIN products  p ON p.id = r.product_id
WHERE NOT EXISTS (
    SELECT 1
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.id
    WHERE o.customer_id = r.customer_id
      AND oi.product_id = r.product_id
      AND o.status = 'delivered'
)
ORDER BY r.id;

-- Задача 17. Заказ доставлен на чужой адрес
SELECT o.id, o.customer_id, a.customer_id AS address_owner
FROM orders o
JOIN addresses a ON a.id = o.address_id
WHERE a.customer_id <> o.customer_id;

-- Задача 18. Цена в позиции заказа отличается от текущей цены товара
SELECT oi.order_id, p.name, oi.unit_price, p.price
FROM order_items oi
JOIN products p ON p.id = oi.product_id
WHERE oi.unit_price <> p.price;


-- ============================================================================
-- Уровень 4. Подзапросы, CTE, оконные функции
-- ============================================================================

-- Задача 19. Самый дорогой товар в каждой категории
SELECT category, name, model, price
FROM (
    SELECT c.name AS category, p.name, p.model, p.price,
           ROW_NUMBER() OVER (PARTITION BY c.id ORDER BY p.price DESC) AS rn
    FROM products p
    JOIN categories c ON c.id = p.category_id
) t
WHERE rn = 1
ORDER BY price DESC;
-- PostgreSQL-вариант покороче:
-- SELECT DISTINCT ON (c.id) c.name, p.name, p.price
-- FROM products p JOIN categories c ON c.id = p.category_id
-- ORDER BY c.id, p.price DESC;

-- Задача 20. Первый и последний заказ каждого покупателя и сколько дней между ними
SELECT c.name,
       COUNT(o.id)                                    AS orders_cnt,
       MIN(o.created_at)::DATE                        AS first_order,
       MAX(o.created_at)::DATE                        AS last_order,
       MAX(o.created_at)::DATE - MIN(o.created_at)::DATE AS days_between
FROM customers c
JOIN orders o ON o.customer_id = c.id
GROUP BY c.id, c.name
HAVING COUNT(o.id) >= 2
ORDER BY days_between DESC;

-- Задача 21. Доля повторных покупателей (2+ заказа) среди всех, кто что-то заказывал
WITH per_customer AS (
    SELECT customer_id, COUNT(*) AS cnt
    FROM orders
    GROUP BY customer_id
)
SELECT COUNT(*) FILTER (WHERE cnt >= 2)                              AS repeat_buyers,
       COUNT(*)                                                       AS all_buyers,
       ROUND(COUNT(*) FILTER (WHERE cnt >= 2) * 100.0 / COUNT(*), 1) AS repeat_pct
FROM per_customer;

-- Задача 22. Выручка по месяцам и рост к предыдущему месяцу в %
WITH monthly AS (
    SELECT DATE_TRUNC('month', o.created_at)::DATE AS month,
           SUM(oi.quantity * oi.unit_price)        AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.id
    WHERE o.status IN ('paid', 'shipped', 'delivered')
    GROUP BY month
)
SELECT month,
       revenue,
       LAG(revenue) OVER (ORDER BY month) AS prev_revenue,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY month))
             / LAG(revenue) OVER (ORDER BY month) * 100, 1) AS growth_pct
FROM monthly
ORDER BY month;

-- Задача 23. Номер заказа в истории покупателя и изменение суммы к прошлому заказу
SELECT customer_id,
       id AS order_id,
       created_at::DATE,
       total,
       ROW_NUMBER() OVER w                AS order_no,
       total - LAG(total) OVER w          AS diff_vs_prev
FROM orders
WHERE customer_id = 6
WINDOW w AS (PARTITION BY customer_id ORDER BY created_at)
ORDER BY created_at;

-- Задача 24. Товары с рейтингом ниже среднего по своей категории
-- Окно нельзя использовать в WHERE, поэтому фильтр — во внешнем запросе:
SELECT name, model, avg_rating, category_avg
FROM (
    SELECT pr.name, pr.model,
           ROUND(pr.avg_rating, 2) AS avg_rating,
           ROUND(AVG(pr.avg_rating) OVER (PARTITION BY pr.category_id), 2) AS category_avg
    FROM (
        SELECT p.id, p.name, p.model, p.category_id, AVG(r.rating) AS avg_rating
        FROM products p
        JOIN reviews r ON r.product_id = p.id
        WHERE p.category_id IS NOT NULL
        GROUP BY p.id, p.name, p.model, p.category_id
    ) pr
) t
WHERE avg_rating < category_avg
ORDER BY category_avg - avg_rating DESC;

-- Задача 25. Какие товары чаще всего покупают вместе
SELECT p1.name || ' ' || p1.model AS product_1,
       p2.name || ' ' || p2.model AS product_2,
       COUNT(*) AS together_cnt
FROM order_items a
JOIN order_items b ON b.order_id = a.order_id AND b.product_id > a.product_id
JOIN products p1   ON p1.id = a.product_id
JOIN products p2   ON p2.id = b.product_id
GROUP BY p1.id, p1.name, p1.model, p2.id, p2.name, p2.model
HAVING COUNT(*) >= 2
ORDER BY together_cnt DESC, product_1;

-- Задача 26. «Уснувшие» покупатели: последний заказ больше 120 дней назад
SELECT c.name, c.email, MAX(o.created_at)::DATE AS last_order,
       DATE '2026-10-10' - MAX(o.created_at)::DATE AS days_ago
FROM customers c
JOIN orders o ON o.customer_id = c.id
GROUP BY c.id, c.name, c.email
HAVING MAX(o.created_at) < DATE '2026-10-10' - INTERVAL '120 days'
ORDER BY last_order;

-- Задача 27. ABC-анализ: доля товара в выручке нарастающим итогом
-- A — товары, дающие первые 80 % выручки, B — следующие 15 %, C — остальные 5 %.
WITH product_revenue AS (
    SELECT p.name || ' ' || p.model AS name, SUM(oi.quantity * oi.unit_price) AS revenue
    FROM order_items oi
    JOIN orders   o ON o.id = oi.order_id
    JOIN products p ON p.id = oi.product_id
    WHERE o.status IN ('paid', 'shipped', 'delivered')
    GROUP BY p.id, p.name, p.model   -- по id: у разных моделей бывает одинаковое название
),
cumulative AS (
    SELECT name, revenue,
           SUM(revenue) OVER (ORDER BY revenue DESC, name) * 100.0
               / SUM(revenue) OVER () AS cum_pct
    FROM product_revenue
)
SELECT name, revenue, ROUND(cum_pct, 1) AS cum_pct,
       CASE WHEN cum_pct <= 80 THEN 'A'
            WHEN cum_pct <= 95 THEN 'B'
            ELSE 'C' END AS abc_class
FROM cumulative
ORDER BY revenue DESC;

-- Задача 28. Сводка по классам ABC (продолжение задачи 27)
WITH product_revenue AS (
    SELECT p.name || ' ' || p.model AS name, SUM(oi.quantity * oi.unit_price) AS revenue
    FROM order_items oi
    JOIN orders   o ON o.id = oi.order_id
    JOIN products p ON p.id = oi.product_id
    WHERE o.status IN ('paid', 'shipped', 'delivered')
    GROUP BY p.id, p.name, p.model   -- по id: у разных моделей бывает одинаковое название
),
classified AS (
    SELECT revenue,
           CASE WHEN SUM(revenue) OVER (ORDER BY revenue DESC, name) * 100.0
                     / SUM(revenue) OVER () <= 80 THEN 'A'
                WHEN SUM(revenue) OVER (ORDER BY revenue DESC, name) * 100.0
                     / SUM(revenue) OVER () <= 95 THEN 'B'
                ELSE 'C' END AS abc_class
    FROM product_revenue
)
SELECT abc_class, COUNT(*) AS products_cnt, SUM(revenue) AS revenue
FROM classified
GROUP BY abc_class
ORDER BY abc_class;
