-- ============================================================================
-- ТехноМир — Часть 6. Транзакции, COMMIT, ROLLBACK
-- Выполнять ВРУЧНУЮ, пошагово. Для 6.3, 6.6 и вопроса про изоляцию нужны
-- ДВЕ НЕЗАВИСИМЫЕ СЕССИИ: в DBeaver — два SQL-редактора с отдельными
-- соединениями (Open separate connection), в pgAdmin — два окна Query Tool.
-- В DBeaver переключите режим на Manual commit (кнопка Auto/Manual на панели),
-- иначе каждый оператор будет коммититься сам.
-- ============================================================================


-- ---- 6.1. Оформление заказа — атомарно -------------------------------------
-- Покупатель 3 (Елена Кузнецова) покупает 1 стиральную машину LG (товар 6)
-- и 2 электрочайника Tefal (товар 15).
BEGIN;

-- 1. Заказ
INSERT INTO orders (customer_id, address_id, status)
VALUES (3, 4, 'paid')
RETURNING id;                                   -- запомните id, ниже он берётся через currval

-- 2. Две позиции (цена — текущая цена товара)
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT currval('orders_id_seq'), id, 1, price FROM products WHERE id = 6;
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT currval('orders_id_seq'), id, 2, price FROM products WHERE id = 15;

-- 3. Списание со склада
UPDATE products SET stock = stock - 1 WHERE id = 6;
UPDATE products SET stock = stock - 2 WHERE id = 15;

-- 5. Итоговая сумма заказа = сумма позиций (шаг 5 выполняем до платежа,
--    чтобы платёж взял уже посчитанную сумму)
UPDATE orders
SET total = (SELECT SUM(quantity * unit_price) FROM order_items WHERE order_id = currval('orders_id_seq'))
WHERE id = currval('orders_id_seq');

-- 4. Платёж на всю сумму
INSERT INTO payments (order_id, amount, method, status)
SELECT id, total, 'card', 'completed' FROM orders WHERE id = currval('orders_id_seq');

COMMIT;

-- Проверка: всё записалось
SELECT o.id, o.status, o.total,
       (SELECT COUNT(*) FROM order_items oi WHERE oi.order_id = o.id) AS items,
       (SELECT SUM(amount) FROM payments p WHERE p.order_id = o.id)  AS paid
FROM orders o
ORDER BY o.id DESC
LIMIT 1;
-- 1 строка: items = 2, total = 34 990 + 2 × 3 490 = 41 970, paid = 41 970
SELECT id, stock FROM products WHERE id IN (6, 15);
-- stock уменьшился: товар 6 — с 10 до 9, товар 15 — с 25 до 23


-- ---- 6.2. ROLLBACK ---------------------------------------------------------
-- Тот же сценарий, но на шаге 3 списываем больше, чем есть на складе.
-- Товар 3 (холодильник Bosch) — на складе 4 шт., покупаем 50.
BEGIN;

INSERT INTO orders (customer_id, address_id, status) VALUES (3, 4, 'new') RETURNING id;

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT currval('orders_id_seq'), id, 50, price FROM products WHERE id = 3;

UPDATE products SET stock = stock - 50 WHERE id = 3;
-- ERROR: new row for relation "products" violates check constraint "products_stock_check"
-- После ошибки транзакция в состоянии aborted — любые команды, кроме ROLLBACK, отклоняются:
-- ERROR: current transaction is aborted, commands ignored until end of transaction block

ROLLBACK;

-- Проверка: заказ из шага 1 и позиция из шага 2 исчезли
SELECT COUNT(*) AS orders_with_50_fridges
FROM order_items WHERE product_id = 3 AND quantity = 50;     -- 0
SELECT stock FROM products WHERE id = 3;                     -- по-прежнему 4
-- Замечание: id заказа из отменённой транзакции «сгорел» — sequence не откатывается,
-- поэтому в orders будет пропуск номера. Это нормально.


-- ---- 6.3. Что видит другая сессия ------------------------------------------
-- СЕССИЯ 1:
BEGIN;
UPDATE products SET price = 1 WHERE id = 1;
--   (COMMIT пока НЕ делаем)

-- СЕССИЯ 2:
SELECT price FROM products WHERE id = 1;
--   Видит СТАРУЮ цену 64 990. Незакоммиченные изменения другой транзакции
--   не видны: в PostgreSQL нет dirty read даже на READ UNCOMMITTED.

-- СЕССИЯ 1:
COMMIT;

-- СЕССИЯ 2:
SELECT price FROM products WHERE id = 1;
--   Теперь видит 1.00.

-- Вернуть цену (любая сессия):
UPDATE products SET price = 64990.00 WHERE id = 1;


-- ---- 6.4. SAVEPOINT --------------------------------------------------------
-- В схеме password_hash NOT NULL, поэтому добавляем его в INSERT
-- (в тексте задания столбца нет — без него INSERT упал бы на NOT NULL).
BEGIN;
INSERT INTO customers (email, password_hash, name) VALUES ('a@test.com', 'hash', 'A');
SAVEPOINT after_customer;
INSERT INTO customers (email, password_hash, name) VALUES ('a@test.com', 'hash', 'Дубль');
-- ERROR: duplicate key value violates unique constraint "customers_email_key"
ROLLBACK TO SAVEPOINT after_customer;      -- откат только до точки, 'A' сохраняется
INSERT INTO customers (email, password_hash, name) VALUES ('b@test.com', 'hash', 'B');
COMMIT;

SELECT email, name FROM customers WHERE email IN ('a@test.com', 'b@test.com');
-- 2 строки: добавились A и B, «Дубль» — нет.

-- Проверка без SAVEPOINT: транзакция переходит в aborted, COMMIT = ROLLBACK
BEGIN;
INSERT INTO customers (email, password_hash, name) VALUES ('c@test.com', 'hash', 'C');
INSERT INTO customers (email, password_hash, name) VALUES ('c@test.com', 'hash', 'Дубль');
-- ERROR: duplicate key ...
INSERT INTO customers (email, password_hash, name) VALUES ('d@test.com', 'hash', 'D');
-- ERROR: current transaction is aborted, commands ignored until end of transaction block
COMMIT;
-- Ответ сервера: ROLLBACK — PostgreSQL превратил COMMIT в откат.
SELECT COUNT(*) FROM customers WHERE email IN ('c@test.com', 'd@test.com');   -- 0

-- Убрать тестовых покупателей:
DELETE FROM customers WHERE email IN ('a@test.com', 'b@test.com');


-- ---- 6.5. Autocommit -------------------------------------------------------
-- psql:  \echo :AUTOCOMMIT     -> on
-- DBeaver: режим Auto-commit на панели инструментов.
-- Выполните БЕЗ BEGIN (в режиме autocommit):
UPDATE products SET stock = stock + 1 WHERE id = 2;
ROLLBACK;
-- WARNING: there is no transaction in progress
-- Изменение НЕ откатилось: в autocommit каждый оператор — отдельная транзакция,
-- которая коммитится сразу после выполнения. ROLLBACK откатывать нечего.
SELECT stock FROM products WHERE id = 2;       -- 6 вместо 5
UPDATE products SET stock = stock - 1 WHERE id = 2;   -- вернуть


-- ---- 6.6. Блокировки и deadlock --------------------------------------------
-- Шаги строго по очереди между двумя сессиями:
-- СЕССИЯ 1:
BEGIN;
UPDATE products SET stock = stock - 1 WHERE id = 1;     -- блокирует строку 1
-- СЕССИЯ 2:
BEGIN;
UPDATE products SET stock = stock - 1 WHERE id = 2;     -- блокирует строку 2
-- СЕССИЯ 1:
UPDATE products SET stock = stock - 1 WHERE id = 2;     -- ЗАВИСАЕТ: ждёт сессию 2
-- СЕССИЯ 2:
UPDATE products SET stock = stock - 1 WHERE id = 1;     -- взаимное ожидание
-- Примерно через 1 секунду (deadlock_timeout) одна из сессий получает:
-- ERROR: deadlock detected
-- DETAIL: Process 123 waits for ShareLock on transaction 456; blocked by process 789.
--         Process 789 waits for ShareLock on transaction 457; blocked by process 123.
-- HINT: See server log for query details.
-- Откатывается транзакция той сессии, которая получила ошибку (обычно — та,
-- что «замкнула» цикл, т.е. сессия 2). Вторая сессия продолжает работу.
-- Завершить обе:
ROLLBACK;   -- в обеих сессиях (в упавшей транзакция уже aborted)


-- ---- 6.7. Non-repeatable read: READ COMMITTED vs REPEATABLE READ -----------

-- Вариант 1 — READ COMMITTED (уровень по умолчанию в PostgreSQL)
-- СЕССИЯ 1:
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT price FROM products WHERE id = 10;    -- 8 990
-- СЕССИЯ 2 (autocommit):
UPDATE products SET price = 9990 WHERE id = 10;
-- СЕССИЯ 1:
SELECT price FROM products WHERE id = 10;    -- 9 990 — внутри ОДНОЙ транзакции значение изменилось
COMMIT;                                      -- это и есть non-repeatable read

-- Вернуть цену:
UPDATE products SET price = 8990 WHERE id = 10;

-- Вариант 2 — REPEATABLE READ
-- СЕССИЯ 1:
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT price FROM products WHERE id = 10;    -- 8 990 (снимок фиксируется на первом запросе)
-- СЕССИЯ 2 (autocommit):
UPDATE products SET price = 9990 WHERE id = 10;
-- СЕССИЯ 1:
SELECT price FROM products WHERE id = 10;    -- по-прежнему 8 990 — аномалия исчезла
COMMIT;
SELECT price FROM products WHERE id = 10;    -- после конца транзакции видно 9 990

-- Вернуть цену:
UPDATE products SET price = 8990 WHERE id = 10;
