-- ============================================================================
-- ТехноМир — Часть 9. Must-have команды
-- Запускается на чистых данных (schema.sql + data.sql). Всё, что меняет
-- данные или права, обёрнуто в BEGIN ... ROLLBACK либо убирает за собой.
-- Количество строк в комментариях — результат на чистых тестовых данных.
-- ============================================================================


-- ---- 9.1. Оконные функции --------------------------------------------------

-- Задание 9.1: нумерация товаров внутри категории по убыванию цены
SELECT COALESCE(c.name, 'Без категории') AS category,
       p.name, p.price,
       ROW_NUMBER() OVER (PARTITION BY p.category_id ORDER BY p.price DESC) AS rn
FROM products p
LEFT JOIN categories c ON c.id = p.category_id
ORDER BY p.category_id NULLS LAST, rn;
-- 25 строк; нумерация начинается заново в каждой категории

-- Задание 9.1: 2-й по дороговизне товар в каждой категории
-- (оконную функцию нельзя писать в WHERE — сначала считаем её в подзапросе)
SELECT category, name, price
FROM (
    SELECT COALESCE(c.name, 'Без категории') AS category,
           p.name, p.price,
           DENSE_RANK() OVER (PARTITION BY p.category_id ORDER BY p.price DESC) AS rnk
    FROM products p
    LEFT JOIN categories c ON c.id = p.category_id
) t
WHERE rnk = 2;
-- 6 строк — по одной на каждую категорию с товарами, включая «Без категории».
-- Корневая «Крупная техника» товаров напрямую не содержит, поэтому её нет.

-- Задание 9.1: нарастающий итог выручки по месяцам
SELECT month,
       revenue,
       SUM(revenue) OVER (ORDER BY month) AS running_total
FROM (
    SELECT DATE_TRUNC('month', paid_at)::DATE AS month,
           SUM(amount) AS revenue
    FROM payments
    WHERE status = 'completed'
    GROUP BY 1
) m
ORDER BY month;
-- 8 строк; последняя строка running_total = вся выручка

-- Задание 9.1: LAG / LEAD — изменение выручки к прошлому месяцу
SELECT month, revenue,
       LAG(revenue)  OVER (ORDER BY month)            AS prev_month,
       revenue - LAG(revenue) OVER (ORDER BY month)   AS diff,
       LEAD(revenue) OVER (ORDER BY month)            AS next_month
FROM (
    SELECT DATE_TRUNC('month', paid_at)::DATE AS month, SUM(amount) AS revenue
    FROM payments WHERE status = 'completed' GROUP BY 1
) m
ORDER BY month;
-- 8 строк; у первого месяца prev_month = NULL, у последнего next_month = NULL

-- ❓ RANK vs DENSE_RANK vs ROW_NUMBER при одинаковых значениях.
-- У покупателей 1 и 2 по 3 заказа, у семерых — по 2: есть «ничьи».
SELECT c.name,
       COUNT(o.id) AS orders_cnt,
       ROW_NUMBER() OVER (ORDER BY COUNT(o.id) DESC, c.id) AS row_number,
       RANK()       OVER (ORDER BY COUNT(o.id) DESC)       AS rank,
       DENSE_RANK() OVER (ORDER BY COUNT(o.id) DESC)       AS dense_rank
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
GROUP BY c.id, c.name
ORDER BY orders_cnt DESC, c.id;
-- 10 строк:
--   orders_cnt 3 -> row_number 1,2   rank 1,1   dense_rank 1,1
--   orders_cnt 2 -> row_number 3..9  rank 3     dense_rank 2
--   orders_cnt 0 -> row_number 10    rank 10    dense_rank 3
-- ROW_NUMBER всегда уникален, RANK после ничьей пропускает номера, DENSE_RANK — нет.


-- ---- 9.2. CTE (WITH) -------------------------------------------------------

-- Задание 9.2: запрос 4.25 (покупатель с максимальной суммой покупок) через CTE
WITH customer_spent AS (
    SELECT o.customer_id, SUM(pay.amount) AS spent
    FROM orders o
    JOIN payments pay ON pay.order_id = o.id
    GROUP BY o.customer_id
)
SELECT c.id, c.name, cs.spent
FROM customer_spent cs
JOIN customers c ON c.id = cs.customer_id
WHERE cs.spent = (SELECT MAX(spent) FROM customer_spent);
-- 1 строка: Анна Смирнова — тот же результат, что в 4.25, но подзапрос написан один раз

-- Задание 9.2: рекурсивный CTE — дерево категорий с уровнем вложенности
WITH RECURSIVE tree AS (
    -- якорь: корневые категории
    SELECT id, name, parent_id, 1 AS level, name::TEXT AS path
    FROM categories
    WHERE parent_id IS NULL
    UNION ALL
    -- рекурсия: дети уже найденных категорий
    SELECT c.id, c.name, c.parent_id, t.level + 1, t.path || ' > ' || c.name
    FROM categories c
    JOIN tree t ON c.parent_id = t.id
)
SELECT REPEAT('    ', level - 1) || name AS category_tree, level, path
FROM tree
ORDER BY path;
-- 6 строк:
--   Крупная техника (1) -> Стиральные машины (2), Холодильники (2)
--   Мелкая техника (1)  -> Пылесосы (2), Чайники (2)


-- ---- 9.3. STRING_AGG -------------------------------------------------------

-- Задание 9.3: названия товаров заказа одной строкой
SELECT o.id AS order_id,
       STRING_AGG(p.name, ', ' ORDER BY p.name) AS products     -- MySQL: GROUP_CONCAT(p.name SEPARATOR ', ')
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
JOIN products p     ON p.id = oi.product_id
GROUP BY o.id
ORDER BY o.id;
-- 19 строк (у заказа 20 позиций нет, INNER JOIN его исключает)


-- ---- 9.4. UPSERT -----------------------------------------------------------

BEGIN;

-- Задание 9.4: email уже есть -> обновляем телефон вместо ошибки UNIQUE
INSERT INTO customers (email, password_hash, name, phone)
VALUES ('olga.morozova@gmail.com', 'hash', 'Ольга Морозова', '+7 999 000-11-22')
ON CONFLICT (email) DO UPDATE
SET phone = EXCLUDED.phone            -- EXCLUDED — строка, которую пытались вставить
RETURNING id, email, phone;
-- 1 строка: id 5, телефон появился (новая строка не создана)

-- Задание 9.4: email нового нет -> обычная вставка
INSERT INTO customers (email, password_hash, name, phone)
VALUES ('new.client@gmail.com', 'hash', 'Новый Клиент', NULL)
ON CONFLICT (email) DO UPDATE SET phone = EXCLUDED.phone
RETURNING id, email;
-- 1 строка: id 11 — вставка
-- MySQL: INSERT ... ON DUPLICATE KEY UPDATE phone = VALUES(phone)

ROLLBACK;


-- ---- 9.5. LIMIT / OFFSET — пагинация ---------------------------------------

-- Задание 9.5: страницы по 10 товаров
SELECT id, name, price FROM products ORDER BY id LIMIT 10 OFFSET 0;    -- страница 1: 10 строк
SELECT id, name, price FROM products ORDER BY id LIMIT 10 OFFSET 10;   -- страница 2: 10 строк
SELECT id, name, price FROM products ORDER BY id LIMIT 10 OFFSET 20;   -- страница 3: 5 строк (21–25)

-- ❓ Keyset-пагинация: вместо «пропусти N строк» — «дай строки после последнего id».
-- Индекс по id сразу находит место старта, ничего не пропуская.
SELECT id, name, price FROM products
WHERE id > 20            -- 20 = id последней строки предыдущей страницы
ORDER BY id
LIMIT 10;
-- 5 строк — та же страница 3


-- ---- 9.6. Типы и приведение ------------------------------------------------

-- Задание 9.6: CAST, ::, конкатенация
SELECT name,
       price,
       CAST(price AS INT)                       AS price_int,      -- округление до целого
       price::TEXT                              AS price_text,
       name || ' — ' || price::TEXT || ' сом'   AS label           -- MySQL: CONCAT(name, ' — ', price)
FROM products
ORDER BY id
LIMIT 5;
-- 5 строк

-- Задание 9.6: работа с датами
SELECT id,
       created_at,
       EXTRACT(MONTH FROM created_at)        AS month_num,
       EXTRACT(YEAR  FROM created_at)        AS year_num,
       DATE_TRUNC('month', created_at)       AS month_start,
       NOW() - created_at                    AS age,
       created_at + INTERVAL '7 days'        AS delivery_deadline
FROM orders
ORDER BY id
LIMIT 5;
-- 5 строк

-- Заказы за последние 30 дней относительно текущего момента
SELECT id, status, created_at
FROM orders
WHERE created_at >= NOW() - INTERVAL '30 days'
ORDER BY created_at;
-- результат зависит от даты запуска


-- ---- 9.7. GRANT / REVOKE ---------------------------------------------------

-- Задание 9.7: пользователь приложения shop_app — минимум прав (продолжение части 8)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'shop_app') THEN
        CREATE ROLE shop_app LOGIN PASSWORD 'shop_app_pass';
    END IF;
END
$$;

-- Сначала снимаем всё, что могло быть выдано (идемпотентность)
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM shop_app;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM shop_app;

GRANT USAGE ON SCHEMA public TO shop_app;

-- Каталог и заказы: читать, создавать, обновлять. DELETE и DROP — нет.
GRANT SELECT, INSERT, UPDATE ON products, orders, order_items, payments, reviews, addresses
    TO shop_app;
GRANT SELECT ON brands, categories TO shop_app;

-- customers: только перечисленные столбцы, password_hash в список не входит
GRANT SELECT (id, email, name, phone, created_at) ON customers TO shop_app;
GRANT UPDATE (name, phone)                        ON customers TO shop_app;

-- Для INSERT нужны счётчики id
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO shop_app;

-- Проверка: действуем от имени shop_app
SET ROLE shop_app;
SELECT id, email, name FROM customers LIMIT 3;   -- работает
SELECT password_hash FROM customers LIMIT 1;     -- ERROR: permission denied for table customers
-- (выполняйте строки по одной: после ошибки в одной транзакции дальше не пойдёт)
DROP TABLE reviews;                              -- ERROR: must be owner of table reviews
DELETE FROM reviews WHERE id = 1;                -- ERROR: permission denied for table reviews
RESET ROLE;                                      -- вернуться к postgres

-- Проверить выданные права:
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'shop_app'
ORDER BY table_name, privilege_type;


-- ---- 9.8. Уникальность и дубликаты -----------------------------------------
-- В customers email защищён UNIQUE, поэтому дубли делаем во временной копии без ограничений.
CREATE TEMP TABLE customers_dup AS
SELECT id, email, name FROM customers;

INSERT INTO customers_dup (id, email, name) VALUES
    (101, 'anna.smirnova@gmail.com', 'Анна Смирнова (дубль)'),
    (102, 'anna.smirnova@gmail.com', 'Анна Смирнова (ещё дубль)'),
    (103, 'i.petrov@yandex.ru',      'Иван Петров (дубль)');

-- Задание 9.8: найти дубли email
SELECT email, COUNT(*) AS cnt
FROM customers_dup
GROUP BY email
HAVING COUNT(*) > 1;
-- 2 строки: anna.smirnova — 3, i.petrov — 2

-- Задание 9.8: удалить дубли, оставив запись с наименьшим id
DELETE FROM customers_dup
WHERE id IN (
    SELECT id FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY email ORDER BY id) AS rn
        FROM customers_dup
    ) t
    WHERE rn > 1
);
-- DELETE 3
-- Без столбца id можно опираться на системный ctid: ... WHERE ctid IN (...)

SELECT email, COUNT(*) FROM customers_dup GROUP BY email HAVING COUNT(*) > 1;
-- 0 строк — дублей не осталось

DROP TABLE customers_dup;


-- ---- 9.9. EXPLAIN — читаем план -------------------------------------------
EXPLAIN ANALYZE
SELECT c.name, COUNT(o.id) AS orders_cnt
FROM customers c
JOIN orders o ON o.customer_id = c.id
WHERE o.status = 'delivered'
GROUP BY c.name;
/*
  Примерный план и что значит каждая строка (читать снизу вверх, от вложенных узлов):

  HashAggregate  (cost=... rows=...) (actual time=... rows=8 loops=1)
    Group Key: c.name                      <- GROUP BY: группировка через хэш-таблицу
    ->  Hash Join  (...)                   <- соединение двух таблиц по хэшу
          Hash Cond: (o.customer_id = c.id)   <- условие JOIN
          ->  Seq Scan on orders o            <- полный просмотр orders (20 строк — индекс не нужен)
                Filter: (status = 'delivered')   <- WHERE применяется при чтении
                Rows Removed by Filter: 8        <- 20 заказов − 12 доставленных
          ->  Hash                            <- из customers строится хэш-таблица
                ->  Seq Scan on customers c   <- полный просмотр customers
  Planning Time: ...   <- время на выбор плана
  Execution Time: ...  <- реальное время выполнения

  cost=a..b — оценка планировщика (a — до первой строки, b — до последней) в условных единицах;
  rows — ожидаемое число строк; actual time и actual rows — что было на самом деле.
  Большое расхождение rows и actual rows — сигнал, что статистика устарела (нужен ANALYZE).
*/


-- ---- 9.10. Триггер (бонус) -------------------------------------------------
/*
  При вставке в order_items автоматически уменьшает products.stock.
  Демонстрация внутри транзакции: в PostgreSQL DDL тоже транзакционный,
  ROLLBACK убирает и функцию, и триггер — базу не трогаем.
  Чтобы оставить триггер навсегда, замените ROLLBACK на COMMIT — и тогда
  уберите ручное списание stock из place_order (часть 7), иначе товар
  будет списываться дважды.
*/
BEGIN;

CREATE OR REPLACE FUNCTION trg_decrease_stock() RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE products
    SET stock = stock - NEW.quantity
    WHERE id = NEW.product_id;
    -- при нехватке сработает CHECK (stock >= 0) и вставка позиции откатится
    RETURN NEW;
END;
$$;

CREATE TRIGGER order_items_decrease_stock
AFTER INSERT ON order_items
FOR EACH ROW
EXECUTE FUNCTION trg_decrease_stock();

SELECT stock FROM products WHERE id = 15;                       -- 25
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (17, 15, 3, 3490.00);
SELECT stock FROM products WHERE id = 15;                       -- 22 — триггер списал 3 шт.

ROLLBACK;
