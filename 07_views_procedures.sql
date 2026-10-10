-- ============================================================================
-- ТехноМир — Часть 7. Views, процедуры, обслуживание
-- Файл идемпотентный: CREATE OR REPLACE, можно запускать повторно.
-- ============================================================================


-- ---- 7.1. Views ------------------------------------------------------------

/*
  v_order_summary — сводка по заказу: имя покупателя, число позиций, сумма, статус.
  LEFT JOIN к order_items, чтобы в сводку попал и заказ 20 без позиций
  (items_cnt = 0). Сумма берётся из orders.total — это «итоговая сумма»
  с учётом скидок (у заказа 13 она меньше суммы позиций).
*/
CREATE OR REPLACE VIEW v_order_summary AS
SELECT o.id            AS order_id,
       c.name          AS customer_name,
       COUNT(oi.id)    AS items_cnt,
       o.total,
       o.status,
       o.created_at
FROM orders o
JOIN customers c        ON c.id = o.customer_id
LEFT JOIN order_items oi ON oi.order_id = o.id
GROUP BY o.id, c.name, o.total, o.status, o.created_at;

/*
  v_product_stats — товар, категория, средний рейтинг, число продаж, остаток.
  Отзывы и продажи агрегируются в подзапросах ДО соединения: если соединить
  reviews и order_items напрямую, строки перемножатся и COUNT/SUM будут завышены.
  Отменённые заказы в продажи не засчитываются.
*/
CREATE OR REPLACE VIEW v_product_stats AS
SELECT p.id                                   AS product_id,
       p.name                                 AS product_name,
       p.model,
       COALESCE(cat.name, 'Без категории')    AS category,
       p.price,
       COALESCE(r.avg_rating, 0)              AS avg_rating,
       COALESCE(s.sold_qty, 0)                AS sold_qty,
       p.stock
FROM products p
LEFT JOIN categories cat ON cat.id = p.category_id
LEFT JOIN (
    SELECT product_id, ROUND(AVG(rating), 2) AS avg_rating
    FROM reviews
    GROUP BY product_id
) r ON r.product_id = p.id
LEFT JOIN (
    SELECT oi.product_id, SUM(oi.quantity) AS sold_qty
    FROM order_items oi
    JOIN orders o ON o.id = oi.order_id AND o.status <> 'cancelled'
    GROUP BY oi.product_id
) s ON s.product_id = p.id;

-- SELECT из view — как из обычной таблицы
SELECT * FROM v_order_summary ORDER BY order_id;
-- 20 строк; у заказа 20 items_cnt = 0

SELECT * FROM v_order_summary WHERE status = 'new';
-- 4 строки (заказы 17–20)

SELECT * FROM v_product_stats ORDER BY sold_qty DESC, product_id LIMIT 5;
-- 5 строк — самые продаваемые товары

-- ❓ Хранит ли view данные? Проверка: меняем цену и сразу видим её во view.
BEGIN;
UPDATE products SET price = 70000 WHERE id = 1;
SELECT product_id, price FROM v_product_stats WHERE product_id = 1;
-- 70 000 — view не хранит данные, это сохранённый запрос, он выполняется заново при каждом обращении
ROLLBACK;


-- ---- 7.2. Хранимая функция place_order -------------------------------------

/*
  place_order(customer_id, product_id, quantity) -> id нового заказа.
  В PostgreSQL FUNCTION выполняется внутри транзакции вызывающего:
  если внутри возникает исключение, ВСЕ изменения функции откатываются
  автоматически. Поэтому «ROLLBACK при нехватке товара» реализован через
  RAISE EXCEPTION: заказ и позиция, созданные до проверки, исчезнут.
  (COMMIT/ROLLBACK внутри тела разрешены только в PROCEDURE и только при
  вызове CALL вне явной транзакции — вариант с PROCEDURE ниже.)

  Если установлен триггер из 9.10 (списание stock при вставке в order_items),
  ручное списание ниже нужно убрать, иначе товар спишется дважды.
*/
CREATE OR REPLACE FUNCTION place_order(
    p_customer_id INT,
    p_product_id  INT,
    p_quantity    INT
) RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_id INT;
    v_price    DECIMAL(10,2);
    v_stock    INT;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Количество должно быть больше 0, передано %', p_quantity;
    END IF;

    -- FOR UPDATE блокирует строку товара: два одновременных заказа не продадут один остаток дважды
    SELECT price, stock INTO v_price, v_stock
    FROM products
    WHERE id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Товар % не найден', p_product_id;
    END IF;

    INSERT INTO orders (customer_id, status)
    VALUES (p_customer_id, 'new')
    RETURNING id INTO v_order_id;

    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, p_product_id, p_quantity, v_price);

    IF v_stock < p_quantity THEN
        -- исключение откатывает заказ и позицию, созданные выше
        RAISE EXCEPTION 'Недостаточно товара %: на складе %, запрошено %',
                        p_product_id, v_stock, p_quantity;
    END IF;

    UPDATE products SET stock = stock - p_quantity WHERE id = p_product_id;

    UPDATE orders SET total = v_price * p_quantity WHERE id = v_order_id;

    RETURN v_order_id;
END;
$$;

-- Успешный заказ (обёрнут в BEGIN/ROLLBACK, чтобы не менять тестовые данные;
-- для демонстрации COMMIT замените ROLLBACK на COMMIT)
BEGIN;
SELECT place_order(2, 15, 2) AS new_order_id;        -- 2 чайника Tefal, на складе 25
SELECT * FROM v_order_summary ORDER BY order_id DESC LIMIT 1;   -- новый заказ, items_cnt = 1, total = 6 980
SELECT stock FROM products WHERE id = 15;            -- 23
ROLLBACK;

-- Нехватка товара -> исключение -> откат
SELECT place_order(2, 8, 1);
-- ERROR: Недостаточно товара 8: на складе 0, запрошено 1
SELECT COUNT(*) FROM orders;                          -- по-прежнему 20: заказ не остался


-- Вариант PROCEDURE с явными COMMIT / ROLLBACK (PostgreSQL 11+).
-- Вызывать через CALL вне BEGIN (в autocommit), иначе COMMIT внутри запрещён.
CREATE OR REPLACE PROCEDURE place_order_proc(
    p_customer_id INT,
    p_product_id  INT,
    p_quantity    INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_id INT;
    v_price    DECIMAL(10,2);
    v_stock    INT;
BEGIN
    SELECT price, stock INTO v_price, v_stock
    FROM products WHERE id = p_product_id FOR UPDATE;

    INSERT INTO orders (customer_id, status) VALUES (p_customer_id, 'new')
    RETURNING id INTO v_order_id;

    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, p_product_id, p_quantity, v_price);

    IF v_stock IS NULL OR v_stock < p_quantity THEN
        ROLLBACK;                                   -- явный откат заказа и позиции
        RAISE NOTICE 'Заказ отменён: недостаточно товара %', p_product_id;
        RETURN;
    END IF;

    UPDATE products SET stock = stock - p_quantity WHERE id = p_product_id;
    UPDATE orders   SET total = v_price * p_quantity WHERE id = v_order_id;
    COMMIT;                                         -- явная фиксация
    RAISE NOTICE 'Заказ % оформлен', v_order_id;
END;
$$;

-- CALL place_order_proc(2, 8, 1);    -- NOTICE: Заказ отменён: недостаточно товара 8
-- CALL place_order_proc(2, 15, 1);   -- NOTICE: Заказ N оформлен (ВНИМАНИЕ: изменит данные)


-- ---- 7.3. Backup -----------------------------------------------------------
/*
  Выполнять в терминале (не в SQL-редакторе). База работает в Docker-контейнере
  technomir_db, поэтому pg_dump/psql запускаем внутри контейнера:

    # 1. Дамп базы shop в файл на компьютере
    docker exec technomir_db pg_dump -U postgres shop > shop_backup.sql

    # 2. Новая пустая база shop_copy
    docker exec technomir_db psql -U postgres -c "DROP DATABASE IF EXISTS shop_copy;"
    docker exec technomir_db psql -U postgres -c "CREATE DATABASE shop_copy;"

    # 3. Восстановление дампа в shop_copy (-i: передать файл на вход команды)
    docker exec -i technomir_db psql -U postgres -d shop_copy < shop_backup.sql

    # 4. Проверка — скриншот этого вывода приложить в README
    docker exec technomir_db psql -U postgres -d shop_copy -c "\dt"
    docker exec technomir_db psql -U postgres -d shop_copy -c "SELECT COUNT(*) FROM products;"

  shop_backup.sql в .gitignore — в репозиторий не коммитим.
  shop_copy понадобится в части 8.3 (DROP TABLE выполнять только там).
*/


-- ---- 7.4. Комментарии ------------------------------------------------------
-- Выполнено в schema.sql: однострочные -- и многострочные /* ... */
-- комментарии поясняют ON DELETE, DECIMAL, составной ключ, блок ALTER 2.4.
