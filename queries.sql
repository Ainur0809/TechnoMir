-- ============================================================================
-- ТехноМир — queries.sql
-- Запросы из частей 2.3, 3 и 4. Выполняются на базе после schema.sql + data.sql.
-- Количество строк в комментариях — результат на чистых тестовых данных.
--
-- Изменяющие запросы части 3 (UPDATE/DELETE) обёрнуты в BEGIN ... ROLLBACK:
-- видим результат, но данные возвращаются к исходным, чтобы запросы части 4
-- давали те же результаты, а файл можно было прогонять повторно.
-- ============================================================================


-- ============================================================================
-- Часть 2.3. Проверка constraints — каждый запрос должен быть отклонён базой
-- ============================================================================

-- 2.3 ожидаемая ошибка: CHECK price > 0 — холодильник с ценой −5
INSERT INTO products (name, model, price, brand_id, category_id)
VALUES ('Холодильник Samsung', 'RB-TEST', -5, 1, 3);
-- ERROR: new row for relation "products" violates check constraint "products_price_check"

-- 2.3 ожидаемая ошибка: CHECK stock >= 0 — отрицательный остаток
UPDATE products SET stock = -1 WHERE id = 1;
-- ERROR: new row for relation "products" violates check constraint "products_stock_check"

-- 2.3 ожидаемая ошибка: CHECK energy_class — несуществующий класс
UPDATE products SET energy_class = 'D' WHERE id = 1;
-- ERROR: new row for relation "products" violates check constraint "products_energy_class_check"

-- 2.3 ожидаемая ошибка: UNIQUE (product_id, customer_id) — второй отзыв покупателя 3 на стиральную машину 5
INSERT INTO reviews (product_id, customer_id, rating, comment)
VALUES (5, 3, 4, 'Повторный отзыв');
-- ERROR: duplicate key value violates unique constraint "reviews_product_id_customer_id_key"

-- 2.3 ожидаемая ошибка: CHECK rating BETWEEN 1 AND 5
INSERT INTO reviews (product_id, customer_id, rating) VALUES (2, 1, 6);
-- ERROR: new row for relation "reviews" violates check constraint "reviews_rating_check"

-- 2.3 ожидаемая ошибка: FOREIGN KEY — заказ с несуществующим customer_id
INSERT INTO orders (customer_id) VALUES (999);
-- ERROR: insert or update on table "orders" violates foreign key constraint "orders_customer_id_fkey"

-- 2.3 ожидаемая ошибка: CHECK status IN (...) — неизвестный статус заказа
INSERT INTO orders (customer_id, status) VALUES (1, 'lost');
-- ERROR: new row for relation "orders" violates check constraint "orders_status_check"

-- 2.3 ожидаемая ошибка: UNIQUE email — покупатель с уже занятым email
INSERT INTO customers (email, password_hash, name)
VALUES ('anna.smirnova@gmail.com', 'hash', 'Анна Дубль');
-- ERROR: duplicate key value violates unique constraint "customers_email_key"

-- 2.3 ожидаемая ошибка: NOT NULL — покупатель без email
INSERT INTO customers (email, password_hash, name) VALUES (NULL, 'hash', 'Без почты');
-- ERROR: null value in column "email" of relation "customers" violates not-null constraint

-- 2.3 ожидаемая ошибка: PRIMARY KEY — повтор существующего id
INSERT INTO brands (id, name) VALUES (1, 'Haier');
-- ERROR: duplicate key value violates unique constraint "brands_pkey"

-- 2.3 ожидаемая ошибка: составной PRIMARY KEY (product_id, supplier_id) — повтор пары
INSERT INTO product_suppliers (product_id, supplier_id, supply_price) VALUES (1, 1, 40000);
-- ERROR: duplicate key value violates unique constraint "product_suppliers_pkey"

-- 2.3 ожидаемая ошибка: CHECK quantity > 0 — позиция заказа с нулевым количеством
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES (1, 2, 0, 59990);
-- ERROR: new row for relation "order_items" violates check constraint "order_items_quantity_check"

-- 2.3 ожидаемая ошибка: UNIQUE sku (добавлен в 2.4) — два товара с одним артикулом
BEGIN;
UPDATE products SET sku = 'SAM-RB38T600' WHERE id = 1;
UPDATE products SET sku = 'SAM-RB38T600' WHERE id = 4;
-- ERROR: duplicate key value violates unique constraint "uq_products_sku"
ROLLBACK;

-- 2.3 DEFAULT нарушить нельзя — проверяем, что он подставляется.
-- Заказ без status и created_at получает 'new' и текущее время.
BEGIN;
INSERT INTO orders (customer_id) VALUES (10) RETURNING id, status, total, created_at;
-- 1 строка: status = 'new', total = 0.00, created_at = момент вставки
ROLLBACK;


-- ============================================================================
-- Часть 3. CRUD
-- ============================================================================

-- ---- 3.1 Create — см. data.sql (многострочные INSERT, INSERT ... SELECT) ----

-- ---- 3.2 Read ---------------------------------------------------------------

-- Задание 3.2: количество строк в каждой таблице
SELECT 'customers' AS table_name, COUNT(*) FROM customers
UNION ALL SELECT 'addresses',         COUNT(*) FROM addresses
UNION ALL SELECT 'brands',            COUNT(*) FROM brands
UNION ALL SELECT 'categories',        COUNT(*) FROM categories
UNION ALL SELECT 'suppliers',         COUNT(*) FROM suppliers
UNION ALL SELECT 'products',          COUNT(*) FROM products
UNION ALL SELECT 'product_suppliers', COUNT(*) FROM product_suppliers
UNION ALL SELECT 'orders',            COUNT(*) FROM orders
UNION ALL SELECT 'order_items',       COUNT(*) FROM order_items
UNION ALL SELECT 'payments',          COUNT(*) FROM payments
UNION ALL SELECT 'reviews',           COUNT(*) FROM reviews;
-- 11 строк: 30, 36, 10, 10, 8, 60, 31, 60, 140, 50, 50 — все объёмы не меньше требуемых в 3.1

-- Задание 3.2: первые 5 товаров (PostgreSQL / MySQL)
SELECT * FROM products ORDER BY id LIMIT 5;
-- 5 строк

-- Задание 3.2: то же по стандарту SQL (SQL Server: SELECT TOP 5 * FROM products)
SELECT * FROM products ORDER BY id FETCH FIRST 5 ROWS ONLY;
-- 5 строк

-- ---- 3.3 Update -------------------------------------------------------------
BEGIN;

-- Задание 3.3: поднять цены в категории «Холодильники» на 10 %
UPDATE products
SET price = ROUND(price * 1.10, 2)
WHERE category_id = (SELECT id FROM categories WHERE name = 'Холодильники');
-- UPDATE 7 (все холодильники)

-- Задание 3.3: заказы paid старше 3 дней -> shipped
UPDATE orders
SET status = 'shipped'
WHERE status = 'paid'
  AND created_at < CURRENT_TIMESTAMP - INTERVAL '3 days';
-- UPDATE 2 (заказы 16 и 60; число зависит от текущей даты)

-- Задание 3.3: is_default = TRUE только у одного адреса каждого покупателя
-- (основным считаем адрес с наименьшим id, остальные — FALSE)
UPDATE addresses a
SET is_default = (a.id = (SELECT MIN(a2.id) FROM addresses a2 WHERE a2.customer_id = a.customer_id));
-- UPDATE 36 (все адреса)

-- Проверка: у каждого покупателя ровно один основной адрес
SELECT customer_id, COUNT(*) FILTER (WHERE is_default) AS default_cnt
FROM addresses
GROUP BY customer_id
HAVING COUNT(*) FILTER (WHERE is_default) <> 1;
-- 0 строк — ожидаемо

ROLLBACK;

-- ---- 3.4 Delete -------------------------------------------------------------
BEGIN;

-- Задание 3.4: удалить отзывы с рейтингом 1 от покупателей без заказов
DELETE FROM reviews r
WHERE r.rating = 1
  AND NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = r.customer_id);
-- DELETE 1 (отзыв покупателя 10 на робот-пылесос; отзыв с рейтингом 1 от покупателя 9 остался — у него есть заказы)

-- Задание 3.4: удалить заказ, у которого есть позиции и платёж (заказ 1)
SELECT
    (SELECT COUNT(*) FROM order_items WHERE order_id = 1) AS items,
    (SELECT COUNT(*) FROM payments    WHERE order_id = 1) AS payments;
-- до удаления: items = 2, payments = 1

DELETE FROM orders WHERE id = 1;
-- DELETE 1

SELECT
    (SELECT COUNT(*) FROM order_items WHERE order_id = 1) AS items,
    (SELECT COUNT(*) FROM payments    WHERE order_id = 1) AS payments;
-- после: items = 0, payments = 0.
-- order_items и payments ссылаются на orders с ON DELETE CASCADE,
-- поэтому позиции и платёж удалились вместе с заказом.

-- Задание 3.4: удалить категорию, в которой есть товары («Холодильники»)
DELETE FROM categories WHERE name = 'Холодильники';
-- DELETE 1 — удаление прошло.
-- products.category_id объявлен с ON DELETE SET NULL: 7 холодильников остались,
-- но без категории. Если бы стоял RESTRICT, база отказала бы с ошибкой FK.
SELECT id, name, category_id FROM products WHERE name ILIKE 'Холодильник%';
-- 7 строк, category_id = NULL

ROLLBACK;

-- ---- 3.5 NULL ---------------------------------------------------------------

-- Задание 3.5: сравнение с NULL через «=»
SELECT * FROM customers WHERE phone = NULL;
-- 0 строк: phone = NULL даёт NULL (неизвестно), а не TRUE, поэтому WHERE отбрасывает все строки

-- Задание 3.5: правильная проверка на NULL
SELECT * FROM customers WHERE phone IS NULL;
-- 4 строки (покупатели 5, 9, 17, 24)

-- Задание 3.5: NULL = NULL и NULL IS NULL
SELECT NULL = NULL AS eq, NULL IS NULL AS is_null;
-- 1 строка: eq = NULL (пусто), is_null = TRUE


-- ============================================================================
-- Часть 4. Запросы
-- ============================================================================

-- ---- 4.1 Фильтрация и сортировка --------------------------------------------

-- Задание 4.1.1: товары дороже 10 000 и в наличии, по цене убыв., затем по названию
SELECT id, name, model, price, stock
FROM products
WHERE price > 10000 AND stock > 0
ORDER BY price DESC, name;
-- 34 строки — ожидаемо (товары 8, 12, 25 дороже 10 000, но stock = 0)

-- Задание 4.1.2: уникальные города из адресов
SELECT DISTINCT city
FROM addresses
ORDER BY city;
-- 13 строк (36 адресов, города повторяются)

-- Задание 4.1.3: покупатели с email на @gmail.com и с телефоном
SELECT id, name, email, phone
FROM customers
WHERE email LIKE '%@gmail.com' AND phone IS NOT NULL;
-- 9 строк (1, 4, 8, 11, 14, 20, 23, 26, 29) — ожидаемо: у покупателей 5 и 17 тоже gmail, но нет телефона

-- Задание 4.1.4а: товары брендов Samsung и LG через JOIN + IN
SELECT p.id, p.name, p.model, b.name AS brand
FROM products p
JOIN brands b ON b.id = p.brand_id
WHERE b.name IN ('Samsung', 'LG')
ORDER BY b.name, p.price;
-- 15 строк (Samsung 8, LG 7)

-- Задание 4.1.4б: товары со словом «холодильник» в названии
-- LIKE чувствителен к регистру, поэтому ILIKE (MySQL: LIKE с регистронезависимой collation)
SELECT id, name, model
FROM products
WHERE name ILIKE '%холодильник%';
-- 7 строк. С LIKE '%холодильник%' — 0 строк: названия начинаются с заглавной «Х».

-- Задание 4.1.5: заказы со статусом paid или shipped
SELECT id, customer_id, status, total, created_at
FROM orders
WHERE status IN ('paid', 'shipped');
-- 12 строк (10 shipped, 2 paid)

-- Задание 4.1.6: заказы за октябрь 2026 через BETWEEN
SELECT id, status, created_at
FROM orders
WHERE created_at BETWEEN '2026-10-01' AND '2026-10-31';
-- 9 строк (16–20, 57–60). Ловушка: '2026-10-31' означает 2026-10-31 00:00:00,
-- поэтому заказ 31 октября в 15:00 сюда не попал бы. Надёжный вариант:
SELECT id, status, created_at
FROM orders
WHERE created_at >= '2026-10-01' AND created_at < '2026-11-01';
-- 9 строк

-- Задание 4.1.7а: товары НЕ из категории «Холодильники» через NOT IN
SELECT id, name, category_id
FROM products
WHERE category_id NOT IN (SELECT id FROM categories WHERE name = 'Холодильники');
-- 51 строка: 60 − 7 холодильников − 2 товара без категории.
-- category_id NULL: NULL NOT IN (3) даёт NULL, а не TRUE, поэтому товары 23 и 24 пропали.

-- Задание 4.1.7б: то же через NOT EXISTS
SELECT p.id, p.name, p.category_id
FROM products p
WHERE NOT EXISTS (
    SELECT 1 FROM categories c
    WHERE c.id = p.category_id AND c.name = 'Холодильники'
);
-- 53 строки: NOT EXISTS возвращает TRUE для товаров без категории, они попали в выборку.
-- Вывод: при наличии NULL NOT IN и NOT EXISTS дают разные результаты.

-- Задание 4.1.8: алиасы столбцов и таблицы
SELECT p.name,
       p.price        AS price_kgs,
       p.price * 1.12 AS price_with_vat
FROM products p;
-- 60 строк

-- Задание 4.1.9: товары класса A++ или A+ мощностью до 2000 Вт с брендом и категорией
SELECT p.name, p.model, p.energy_class, p.power_watt,
       b.name AS brand, c.name AS category
FROM products p
JOIN brands b          ON b.id = p.brand_id
LEFT JOIN categories c ON c.id = p.category_id   -- LEFT: у очистителя воздуха нет категории
WHERE p.energy_class IN ('A++', 'A+')
  AND p.power_watt <= 2000;
-- 9 строк: 6 холодильников, стиральные машины LG F2J3HS0W и Haier HW70, очиститель воздуха Xiaomi

-- ---- 4.2 Агрегаты -----------------------------------------------------------

-- Задание 4.2.9: количество товаров, мин./макс./средняя цена по каждой категории
SELECT COALESCE(c.name, 'Без категории') AS category,
       COUNT(*)              AS products_cnt,
       MIN(p.price)          AS min_price,
       MAX(p.price)          AS max_price,
       ROUND(AVG(p.price), 2) AS avg_price
FROM products p
LEFT JOIN categories c ON c.id = p.category_id
GROUP BY c.name
ORDER BY products_cnt DESC;
-- 10 строк: Кухонная техника 12, Пылесосы 10, Холодильники / Стиральные машины / Чайники по 7, Телевизоры 6,
-- Микроволновые печи 4, Посудомоечные машины 3, Мелкая техника 2, Без категории 2

-- Задание 4.2.10: сумма оплаченных заказов по месяцам (по дате платежа)
SELECT DATE_TRUNC('month', paid_at)::DATE AS month,
       SUM(amount)                         AS revenue
FROM payments
WHERE status = 'completed'
GROUP BY month
ORDER BY month;
-- 10 строк: январь–октябрь 2026

-- Задание 4.2.11: покупатели, сделавшие более 2 заказов
SELECT c.id, c.name, COUNT(*) AS orders_cnt
FROM customers c
JOIN orders o ON o.customer_id = c.id
GROUP BY c.id, c.name
HAVING COUNT(*) > 2;
-- 12 строк (больше всех у Сергея Волкова — 5 заказов)

-- Задание 4.2.12: товары со средним рейтингом >= 4 и минимум 3 отзывами
SELECT p.id, p.name, ROUND(AVG(r.rating), 2) AS avg_rating, COUNT(*) AS reviews_cnt
FROM products p
JOIN reviews r ON r.product_id = p.id
GROUP BY p.id, p.name
HAVING AVG(r.rating) >= 4 AND COUNT(*) >= 3;
-- 4 строки: холодильник Samsung (4.75), ручной пылесос Xiaomi (4.33), пылесос Redmond (4.67), аэрогриль Philips (4.20)

-- Задание 4.2.13: WHERE vs HAVING (ответ на ❓ — в README)
-- SELECT product_id FROM reviews WHERE AVG(rating) > 4 GROUP BY product_id;
-- ERROR: aggregate functions are not allowed in WHERE
-- WHERE фильтрует строки ДО группировки, агрегата там ещё нет; условие на агрегат — в HAVING:
SELECT product_id, ROUND(AVG(rating), 2) AS avg_rating
FROM reviews
GROUP BY product_id
HAVING AVG(rating) > 4;
-- 13 строк

-- Задание 4.2.14: COUNT(*) vs COUNT(column) vs COUNT(DISTINCT column)
SELECT COUNT(*)              AS all_rows,
       COUNT(phone)          AS with_phone,
       COUNT(DISTINCT phone) AS distinct_phones,
       COUNT(DISTINCT SPLIT_PART(email, '@', 2)) AS distinct_email_domains
FROM customers;
-- 1 строка: 30 / 26 / 26 / 3.
-- COUNT(*) считает все строки, COUNT(phone) пропускает NULL,
-- COUNT(DISTINCT ...) — только уникальные непустые значения (у почтовых доменов их 3).

-- ---- 4.3 JOIN'ы -------------------------------------------------------------

-- Задание 4.3.15: INNER JOIN — позиция заказа, товар, покупатель, статус
SELECT oi.id AS item_id, o.id AS order_id, p.name AS product,
       c.name AS customer, o.status, oi.quantity, oi.unit_price
FROM order_items oi
JOIN orders    o ON o.id = oi.order_id
JOIN products  p ON p.id = oi.product_id
JOIN customers c ON c.id = o.customer_id
ORDER BY o.id, oi.id;
-- 140 строк — все позиции

-- Задание 4.3.16: LEFT JOIN — все покупатели и количество их заказов, включая 0
SELECT c.id, c.name, COUNT(o.id) AS orders_cnt
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
GROUP BY c.id, c.name
ORDER BY orders_cnt DESC, c.id;
-- 30 строк; у покупателей 10, 29, 30 — 0. COUNT(o.id), а не COUNT(*), иначе было бы 1.

-- Задание 4.3.17: RIGHT JOIN — все товары и количество продаж, включая непроданные
SELECT p.id, p.name, COALESCE(SUM(oi.quantity), 0) AS sold_qty
FROM order_items oi
RIGHT JOIN products p ON p.id = oi.product_id
GROUP BY p.id, p.name
ORDER BY sold_qty DESC, p.id;
-- 60 строк; у 10 товаров (например, парогенератора Philips, id 25) — 0

-- Задание 4.3.17: то же через LEFT JOIN (таблицы меняются местами)
SELECT p.id, p.name, COALESCE(SUM(oi.quantity), 0) AS sold_qty
FROM products p
LEFT JOIN order_items oi ON oi.product_id = p.id
GROUP BY p.id, p.name
ORDER BY sold_qty DESC, p.id;
-- 60 строк — тот же результат

-- Задание 4.3.18: FULL JOIN — товары и поставщики, включая товары без поставщика
-- и поставщиков без товаров
SELECT p.name AS product, s.name AS supplier, ps.supply_price
FROM products p
LEFT JOIN product_suppliers ps ON ps.product_id = p.id
FULL JOIN suppliers s          ON s.id = ps.supplier_id
ORDER BY p.id NULLS LAST;
-- 63 строки: 31 поставка + 31 товар без поставщика + 1 поставщик без товаров («Восток-Электро»)
-- MySQL: FULL JOIN нет — эмулируется как LEFT JOIN ... UNION ... RIGHT JOIN (или второй LEFT JOIN)

-- Задание 4.3.19: SELF JOIN — категория и её родительская категория
SELECT c.name AS category, parent.name AS parent_category
FROM categories c
LEFT JOIN categories parent ON parent.id = c.parent_id
ORDER BY c.id;
-- 10 строк; у корневых категорий parent_category = NULL

-- Задание 4.3.20: заказы, где сумма позиций не совпадает с orders.total
SELECT o.id, o.total, SUM(oi.quantity * oi.unit_price) AS items_sum
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
GROUP BY o.id, o.total
HAVING o.total <> SUM(oi.quantity * oi.unit_price);
-- 1 строка: заказ 13 (total 23 980, позиции 24 980 — скидка по промокоду)

-- Задание 4.3.21: круги Эйлера — в README.
-- Строки только из левой таблицы: LEFT JOIN + WHERE правая.id IS NULL.
-- Пример: покупатели без заказов.
SELECT c.id, c.name
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
WHERE o.id IS NULL;
-- 3 строки (Николай Орлов, Фёдор Титов, Лилия Киселёва)

-- ---- 4.4 Объединения и подзапросы -------------------------------------------

-- Задание 4.4.22: единый список контактов — UNION
SELECT email FROM customers
UNION
SELECT email FROM suppliers;
-- 38 строк: UNION убирает дубли (их нет, поэтому 30 + 8)

-- Задание 4.4.22: то же через UNION ALL
SELECT email FROM customers
UNION ALL
SELECT email FROM suppliers;
-- 38 строк: UNION ALL не ищет дубли и поэтому быстрее; здесь результат совпал, т.к. дублей нет

-- Задание 4.4.23а: товары с хотя бы одним отзывом — EXISTS
SELECT p.id, p.name
FROM products p
WHERE EXISTS (SELECT 1 FROM reviews r WHERE r.product_id = p.id);
-- 30 строк

-- Задание 4.4.23б: то же через IN (подзапрос)
SELECT p.id, p.name
FROM products p
WHERE p.id IN (SELECT r.product_id FROM reviews r);
-- 30 строк

-- Задание 4.4.23в: то же через JOIN (DISTINCT нужен: у товара может быть несколько отзывов)
SELECT DISTINCT p.id, p.name
FROM products p
JOIN reviews r ON r.product_id = p.id
ORDER BY p.id;
-- 30 строк (без DISTINCT было бы 50 — по строке на отзыв)

-- Задание 4.4.24а: товары дороже ЛЮБОГО пылесоса (> ANY = дороже самого дешёвого)
SELECT id, name, price
FROM products
WHERE price > ANY (
    SELECT p.price FROM products p JOIN categories c ON c.id = p.category_id
    WHERE c.name = 'Пылесосы'
);
-- 49 строк: дороже 5 990 (самый дешёвый пылесос)

-- Задание 4.4.24б: товары дороже ВСЕХ пылесосов (> ALL = дороже самого дорогого)
SELECT id, name, price
FROM products
WHERE price > ALL (
    SELECT p.price FROM products p JOIN categories c ON c.id = p.category_id
    WHERE c.name = 'Пылесосы'
);
-- 5 строк: дороже 74 990 (Dyson V15) — дорогие холодильники, телевизоры, стирально-сушильная машина

-- Задание 4.4.25: покупатель с максимальной суммой покупок (подзапрос в WHERE)
-- Учитываем только оплаченные платежи.
SELECT c.id, c.name, SUM(pay.amount) AS spent
FROM customers c
JOIN orders   o   ON o.customer_id = c.id
JOIN payments pay ON pay.order_id = o.id
GROUP BY c.id, c.name
HAVING SUM(pay.amount) = (
    SELECT MAX(customer_sum) FROM (
        SELECT SUM(pay2.amount) AS customer_sum
        FROM orders o2
        JOIN payments pay2 ON pay2.order_id = o2.id
        GROUP BY o2.customer_id
    ) t
);
-- 1 строка: Тимур Романов (329 090)

-- Задание 4.4.26: цена товара и средняя цена по его категории — коррелированный подзапрос
SELECT p.id, p.name, p.price,
       (SELECT ROUND(AVG(p2.price), 2) FROM products p2
        WHERE p2.category_id = p.category_id) AS category_avg
FROM products p
ORDER BY p.category_id NULLS LAST, p.price DESC;
-- 60 строк; у товаров без категории category_avg = NULL (NULL = NULL не совпадает)

-- Задание 4.4.26: то же через оконную функцию
SELECT id, name, price,
       ROUND(AVG(price) OVER (PARTITION BY category_id), 2) AS category_avg
FROM products
ORDER BY category_id NULLS LAST, price DESC;
-- 60 строк; окно группирует NULL вместе, поэтому у товаров без категории — их общее среднее

-- ---- 4.5 CASE и NULL-функции ------------------------------------------------

-- Задание 4.5.27: ценовой сегмент
SELECT name, price,
       CASE
           WHEN price < 1000   THEN 'дешёвый'
           WHEN price <= 20000 THEN 'средний'
           ELSE 'дорогой'
       END AS price_segment
FROM products
ORDER BY price;
-- 60 строк: дешёвых 0 (самый дешёвый товар — 1 590), средних 28, дорогих 32

-- Задание 4.5.28: статус заказа на русском
SELECT id, status,
       CASE status
           WHEN 'new'       THEN 'Новый'
           WHEN 'paid'      THEN 'Оплачен'
           WHEN 'shipped'   THEN 'Отправлен'
           WHEN 'delivered' THEN 'Доставлен'
           WHEN 'cancelled' THEN 'Отменён'
       END AS status_ru
FROM orders
ORDER BY id;
-- 60 строк

-- Задание 4.5.29: телефон или «не указан» (MySQL: IFNULL, SQL Server: ISNULL)
SELECT name, COALESCE(phone, 'не указан') AS phone
FROM customers;
-- 30 строк; у четырёх — «не указан»

-- Задание 4.5.30: средний рейтинг товара, без отзывов — 0
SELECT p.id, p.name, COALESCE(ROUND(AVG(r.rating), 2), 0) AS avg_rating
FROM products p
LEFT JOIN reviews r ON r.product_id = p.id
GROUP BY p.id, p.name
ORDER BY avg_rating DESC, p.id;
-- 60 строк; у 30 товаров без отзывов — 0

-- Задание 4.5.31: средний чек покупателя без ошибки деления на 0
-- NULLIF(x, 0) превращает 0 в NULL, а деление на NULL даёт NULL, а не ошибку.
SELECT c.id, c.name,
       COALESCE(SUM(o.total), 0)                  AS revenue,
       COUNT(o.id)                                AS orders_cnt,
       ROUND(SUM(o.total) / NULLIF(COUNT(o.id), 0), 2) AS avg_check
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id AND o.status <> 'cancelled'
GROUP BY c.id, c.name
ORDER BY c.id;
-- 30 строк; у покупателей без заказов (10, 29, 30) avg_check = NULL, ошибки нет

-- ---- 4.6 SELECT INTO / CREATE TABLE AS --------------------------------------

-- Задание 4.6.32: таблица top_products из 5 самых продаваемых товаров
DROP TABLE IF EXISTS top_products;

SELECT p.id, p.name, SUM(oi.quantity) AS sold_qty
INTO top_products                       -- MySQL: CREATE TABLE top_products AS SELECT ...
FROM products p
JOIN order_items oi ON oi.product_id = p.id
JOIN orders o       ON o.id = oi.order_id AND o.status <> 'cancelled'
GROUP BY p.id, p.name
ORDER BY sold_qty DESC, p.id
LIMIT 5;
-- SELECT 5

SELECT * FROM top_products;
-- 5 строк: микроволновка Samsung (8 шт.), чайник Tefal (7), электрогриль Tefal, чайник Xiaomi, аэрогриль Tefal (по 6)
