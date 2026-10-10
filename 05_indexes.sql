-- ============================================================================
-- ТехноМир — Часть 5. Индексы и EXPLAIN
-- Запускать ВРУЧНУЮ в DBeaver/pgAdmin на базе shop, по блокам.
-- Цель — не создать индексы, а увидеть, как они меняют план запроса.
--
-- ВАЖНО: скрипт в конце УДАЛЯЕТ 100 000 сгенерированных строк и лишние
-- индексы, чтобы база вернулась к 25 товарам и запросы частей 3–4,9 давали
-- те же результаты. Пока вы снимаете замеры — не доходите до блока очистки.
-- ============================================================================

-- ---- 5.1. Генерация объёма -------------------------------------------------
-- 25 товаров индекс не покажет. Добавляем 100 000 строк.
-- Имя 'Товар N' выбрано специально, чтобы запрос 5.2 (name = 'Товар 77777')
-- реально находил строку. brand_id и category_id в диапазоне 1..6 — такие
-- бренды и категории уже есть в data.sql.
INSERT INTO products (name, model, price, stock, power_watt, energy_class, brand_id, category_id)
SELECT 'Товар ' || g,
       'BULK',                                   -- метка, по ней удалим строки в конце
       (random() * 50000 + 1000)::DECIMAL(10,2),
       (random() * 100)::INT,
       (random() * 2500)::INT,
       (ARRAY['A++','A+','A','B','C'])[(g % 5) + 1],
       (g % 6) + 1,
       (g % 6) + 1
FROM generate_series(1, 100000) AS g;
-- INSERT 100000.  Теперь в products ~100 025 строк.

ANALYZE products;   -- обновить статистику планировщика после массовой вставки


-- ---- 5.2. Замер ДО индекса -------------------------------------------------
-- Выполните каждый и запишите тип сканирования (ожидается Seq Scan) и время.
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM products WHERE name = 'Товар 77777';
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM products WHERE price BETWEEN 1000 AND 1100;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders   WHERE customer_id = 5;
-- Ожидание: по products — Seq Scan (сканирование всей таблицы).
-- По orders customer_id уже проиндексирован в schema.sql (idx_orders_customer),
-- поэтому там, скорее всего, Index Scan даже сейчас — это тоже результат,
-- запишите его.


-- ---- 5.3. Создаём индексы и повторяем замер --------------------------------
CREATE INDEX IF NOT EXISTS idx_products_name  ON products(name);
CREATE INDEX IF NOT EXISTS idx_products_price ON products(price);
-- idx_orders_customer, idx_order_items_order_product, UNIQUE(customers.email)
-- уже созданы в schema.sql — повторно не создаём (проверка в README 5.5).

ANALYZE products;

-- Те же запросы после индексов — ожидается Index Scan / Bitmap Index Scan.
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM products WHERE name = 'Товар 77777';
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM products WHERE price BETWEEN 1000 AND 1100;
-- Запишите новое время — оно должно упасть на несколько порядков.


-- ---- 5.4. Эксперименты -----------------------------------------------------

-- (а) Функция над столбцом ломает индекс: LOWER(name) обычный idx_products_name
-- использовать НЕ может — Seq Scan.
EXPLAIN ANALYZE SELECT * FROM products WHERE LOWER(name) = 'товар 77777';

-- Функциональный индекс спасает:
CREATE INDEX IF NOT EXISTS idx_products_lower_name ON products(LOWER(name));
ANALYZE products;
EXPLAIN ANALYZE SELECT * FROM products WHERE LOWER(name) = 'товар 77777';
-- Теперь Index Scan по idx_products_lower_name.

-- (б) LIKE: префикс 'Товар 777%' может пользоваться индексом, '%77777' — нет.
EXPLAIN ANALYZE SELECT * FROM products WHERE name LIKE 'Товар 777%';   -- Index Scan возможен
EXPLAIN ANALYZE SELECT * FROM products WHERE name LIKE '%77777';       -- Seq Scan (шаблон с начала неизвестен)
-- Нюанс: индекс по префиксу работает только для C-collation или с классом
-- оператора text_pattern_ops. Если 'Товар 777%' даёт Seq Scan — создайте:
--   CREATE INDEX idx_products_name_pat ON products(name text_pattern_ops);

-- (в) Составной индекс (order_id, product_id): работает ли для WHERE product_id = 3 без order_id?
EXPLAIN ANALYZE SELECT * FROM order_items WHERE product_id = 3;
-- Ожидание: составной индекс (order_id, product_id) по одному product_id
-- обычно НЕ используется эффективно — ведущий столбец order_id в условии
-- отсутствует (правило «левого префикса»). Вероятен Seq Scan.

-- (г) Насколько индекс замедляет вставку. Замеряем 1000 INSERT с индексом и без.
-- С индексом idx_products_price:
EXPLAIN ANALYZE
INSERT INTO products (name, model, price, brand_id, category_id)
SELECT 'InsTest ' || g, 'BULK', 1500, 1, 2 FROM generate_series(1, 1000) AS g;

DROP INDEX IF EXISTS idx_products_price;
-- Без индекса — те же 1000 вставок:
EXPLAIN ANALYZE
INSERT INTO products (name, model, price, brand_id, category_id)
SELECT 'InsTest2 ' || g, 'BULK', 1500, 1, 2 FROM generate_series(1, 1000) AS g;
-- Сравните total time: без индекса вставка быстрее — индекс нужно обновлять на каждую строку.


-- ---- 5.5. Проверка индексов (для ответа на ❓ в README) --------------------
-- \di в psql, либо запрос к каталогу:
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'products' ORDER BY indexname;
-- Видно: products_pkey (от PRIMARY KEY), uq_products_sku (от UNIQUE) созданы
-- автоматически. FOREIGN KEY индекс НЕ создаёт — его добавляли вручную (idx_products_brand и т.п.).


-- ============================================================================
-- ОЧИСТКА. Выполнять ПОСЛЕ того, как все замеры сняты и записаны в README.
-- Возвращает products к исходным 25 строкам и убирает индексы части 5.
-- ============================================================================
DELETE FROM products WHERE model = 'BULK';          -- удалит все сгенерированные строки
SELECT setval('products_id_seq', (SELECT MAX(id) FROM products));  -- вернуть счётчик id к 25

DROP INDEX IF EXISTS idx_products_name;
DROP INDEX IF EXISTS idx_products_price;
DROP INDEX IF EXISTS idx_products_lower_name;
-- idx_products_name_pat тоже удалить, если создавали.

ANALYZE products;
SELECT COUNT(*) AS products_after_cleanup FROM products;   -- ожидается 25
