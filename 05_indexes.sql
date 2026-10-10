-- ============================================================================
-- ТехноМир — Часть 5. Индексы и EXPLAIN
-- Запускать ВРУЧНУЮ в DBeaver/pgAdmin на базе shop, по блокам.
-- Цель — не создать индексы, а увидеть, как они меняют план запроса.
--
-- ВАЖНО: скрипт в конце УДАЛЯЕТ 100 000 сгенерированных строк и лишние
-- индексы, чтобы база вернулась к 60 товарам и запросы частей 3–4, 9 давали
-- те же результаты. Пока вы снимаете замеры — не доходите до блока очистки.
--
-- В DBeaver выполнять по одному запросу: курсор на запрос -> Cmd/Ctrl+Enter.
-- НЕ запускать весь файл (Alt/Option+X) — иначе сразу выполнится и очистка.
-- Время в комментариях — с проверочного прогона, у вас числа будут другими,
-- важен порядок величин и тип сканирования.
-- ============================================================================

-- ---- 5.1. Генерация объёма -------------------------------------------------
-- 60 товаров индекс не покажет. Добавляем 100 000 строк.
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
-- INSERT 100000.  Теперь в products 100 060 строк.

ANALYZE products;   -- обновить статистику планировщика после массовой вставки


-- ---- 5.2. Замер ДО индекса -------------------------------------------------
-- Выполните каждый и запишите тип сканирования (ожидается Seq Scan) и время.
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM products WHERE name = 'Товар 77777';
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM products WHERE price BETWEEN 1000 AND 1100;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders   WHERE customer_id = 5;
-- Ожидание: по products — Seq Scan (сканирование всей таблицы), ~7–20 ms.
-- По orders.customer_id индекс уже есть (idx_orders_customer из schema.sql),
-- но в orders всего 60 строк. Планировщик может выбрать и Seq Scan, и
-- Bitmap Index Scan — на такой маленькой таблице это одинаково быстро
-- (< 0.1 ms). Вывод: индекс окупается только на больших таблицах.


-- ---- 5.3. Создаём индексы и повторяем замер --------------------------------
CREATE INDEX IF NOT EXISTS idx_products_name  ON products(name);
CREATE INDEX IF NOT EXISTS idx_products_price ON products(price);
-- idx_orders_customer, idx_order_items_order_product, UNIQUE(customers.email)
-- уже созданы в schema.sql — повторно не создаём (проверка в README 5.5).

ANALYZE products;

-- Те же запросы после индексов.
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM products WHERE name = 'Товар 77777';
-- Index Scan using idx_products_name, ~0.05 ms (было ~7–13 ms на Seq Scan)
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM products WHERE price BETWEEN 1000 AND 1100;
-- Bitmap Heap Scan + Bitmap Index Scan on idx_products_price, ~0.3–0.6 ms.
-- Bitmap, а не простой Index Scan: подходит ~190 строк, выгоднее сначала
-- собрать номера страниц по индексу, а потом прочитать каждую страницу один раз.


-- ---- 5.4. Эксперименты -----------------------------------------------------

-- (а) Функция над столбцом ломает индекс: LOWER(name) обычный idx_products_name
-- использовать НЕ может — Seq Scan.
EXPLAIN ANALYZE SELECT * FROM products WHERE LOWER(name) = 'товар 77777';
-- Seq Scan, ~28 ms: индекс хранит name как есть, а не LOWER(name)

-- Функциональный индекс спасает:
CREATE INDEX IF NOT EXISTS idx_products_lower_name ON products(LOWER(name));
ANALYZE products;   -- нужен: статистика по выражению LOWER(name) появляется только после ANALYZE
EXPLAIN ANALYZE SELECT * FROM products WHERE LOWER(name) = 'товар 77777';
-- Index Scan using idx_products_lower_name, ~0.04 ms

-- (б) LIKE: '%77777' индекс не использует никогда, 'Товар 777%' — может.
EXPLAIN ANALYZE SELECT * FROM products WHERE name LIKE '%77777';
-- Seq Scan, ~9–14 ms, Rows Removed by Filter: 100059.
-- Шаблон начинается с %, начало строки неизвестно — искать в отсортированном
-- индексе не с чего, приходится проверять все строки.

EXPLAIN ANALYZE SELECT * FROM products WHERE name LIKE 'Товар 777%';
-- Тоже Seq Scan, ~8 ms! База создана с правилами сортировки en_US.utf8
-- (так в Docker-образе postgres), а обычный индекс по такому столбцу
-- для LIKE не подходит. Нужен индекс с классом операторов text_pattern_ops:
CREATE INDEX IF NOT EXISTS idx_products_name_pat ON products(name text_pattern_ops);
EXPLAIN ANALYZE SELECT * FROM products WHERE name LIKE 'Товар 777%';
-- Index Scan using idx_products_name_pat, ~0.08 ms — префиксный LIKE использует индекс.

-- (в) Составной индекс (order_id, product_id): работает ли для WHERE product_id = 3 без order_id?
-- В order_items всего 140 строк — на ней PostgreSQL читает таблицу целиком при
-- любом индексе, вывода не сделать. Поэтому делаем временную копию на 400 000
-- строк с тем же составным индексом. TEMP-таблица видна только в этом
-- подключении и исчезнет сама, когда закроете DBeaver.
CREATE TEMP TABLE oi_big AS
SELECT g / 4 AS order_id, g % 5000 AS product_id, 1 AS quantity
FROM generate_series(1, 400000) AS g;
CREATE INDEX idx_oi_big_order_product ON oi_big(order_id, product_id);
ANALYZE oi_big;

EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM oi_big WHERE order_id = 777;
-- Index Scan using idx_oi_big_order_product, ~0.07 ms — ведущий столбец в условии есть
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM oi_big WHERE product_id = 3;
-- Seq Scan, ~40 ms — индекс тот же, но не используется.
-- Правило «левого префикса»: индекс (order_id, product_id) отсортирован сначала
-- по order_id, а product_id упорядочен только внутри одного order_id.
-- Без order_id в условии искать по индексу не с чего — как телефонная книга,
-- отсортированная по фамилии, бесполезна для поиска только по имени.

-- (г) Насколько индексы замедляют вставку. Вставка 1000 строк в products
-- разницы не покажет: там уже 6 индексов и проверки FK, один индекс тонет в шуме.
-- Поэтому сравниваем на отдельной временной таблице 100 000 вставок
-- без индексов и с тремя индексами.
CREATE TEMP TABLE ins_test (id SERIAL PRIMARY KEY, name VARCHAR(200), price DECIMAL(10,2));

-- Без дополнительных индексов (только первичный ключ):
EXPLAIN ANALYZE
INSERT INTO ins_test (name, price)
SELECT 'Товар ' || g, (random() * 50000)::DECIMAL(10,2) FROM generate_series(1, 100000) AS g;
-- ~240 ms

TRUNCATE ins_test;
CREATE INDEX idx_ins_test_name       ON ins_test(name);
CREATE INDEX idx_ins_test_price      ON ins_test(price);
CREATE INDEX idx_ins_test_lower_name ON ins_test(LOWER(name));

-- Те же 100 000 строк, но теперь на каждую вставку обновляются ещё 3 индекса:
EXPLAIN ANALYZE
INSERT INTO ins_test (name, price)
SELECT 'Товар ' || g, (random() * 50000)::DECIMAL(10,2) FROM generate_series(1, 100000) AS g;
-- ~1 600 ms — примерно в 6–7 раз медленнее.
-- Вывод: индекс ускоряет чтение, но замедляет INSERT/UPDATE/DELETE — каждый
-- индекс нужно обновить для каждой изменённой строки. Индексы стоит создавать
-- под реальные запросы, а не «на всякий случай».

DROP TABLE ins_test;


-- ---- 5.5. Проверка индексов (для ответа на ❓ в README) --------------------
-- \di в psql, либо запрос к каталогу:
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'products' ORDER BY indexname;
-- 7 строк. products_pkey (от PRIMARY KEY) и uq_products_sku (от UNIQUE) созданы
-- автоматически. FOREIGN KEY индекс НЕ создаёт — idx_products_brand и
-- idx_products_category добавлены в schema.sql вручную.


-- ============================================================================
-- ОЧИСТКА. Выполнять ПОСЛЕ того, как все замеры сняты и записаны в README.
-- Возвращает products к исходным 60 строкам и убирает индексы части 5.
-- ============================================================================
DELETE FROM products WHERE model = 'BULK';          -- DELETE 100000
SELECT setval('products_id_seq', (SELECT MAX(id) FROM products));  -- вернуть счётчик id к 60

DROP INDEX IF EXISTS idx_products_name;
DROP INDEX IF EXISTS idx_products_price;
DROP INDEX IF EXISTS idx_products_lower_name;
DROP INDEX IF EXISTS idx_products_name_pat;
DROP TABLE IF EXISTS oi_big;

ANALYZE products;
SELECT COUNT(*) AS products_after_cleanup FROM products;   -- ожидается 60
