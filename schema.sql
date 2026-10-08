-- ============================================================================
-- ТехноМир — schema.sql (PostgreSQL 15+)
-- Часть 2 ДЗ: создание таблиц, constraints, индексов.
-- Скрипт идемпотентный: выполняется с нуля повторно без ошибок (DROP IF EXISTS).
-- ============================================================================

/*
  Задание 2.1 (CREATE DATABASE) выполняется отдельно / через Docker:
  POSTGRES_DB=shop в docker-compose уже создаёт базу.
  Вручную для демонстрации в части 2.1:
      CREATE DATABASE shop;
      DROP DATABASE shop;      -- показать, что скрипт пересоздаёт всё с нуля
  Этот файл запускается уже подключённым к базе shop.
*/

-- ---- Удаление в обратном порядке зависимостей (идемпотентность) -------------
DROP TABLE IF EXISTS product_suppliers CASCADE;
DROP TABLE IF EXISTS reviews           CASCADE;
DROP TABLE IF EXISTS payments          CASCADE;
DROP TABLE IF EXISTS order_items       CASCADE;
DROP TABLE IF EXISTS orders            CASCADE;
DROP TABLE IF EXISTS products          CASCADE;
DROP TABLE IF EXISTS suppliers         CASCADE;
DROP TABLE IF EXISTS categories        CASCADE;
DROP TABLE IF EXISTS brands            CASCADE;
DROP TABLE IF EXISTS addresses         CASCADE;
DROP TABLE IF EXISTS customers         CASCADE;

-- ============================================================================
-- customers — покупатели
-- ============================================================================
CREATE TABLE customers (
    id            SERIAL PRIMARY KEY,
    email         VARCHAR(255) NOT NULL UNIQUE,           -- UNIQUE + NOT NULL
    password_hash VARCHAR(255) NOT NULL,
    full_name     VARCHAR(200) NOT NULL,                  -- в 2.4 будет переименован в name
    phone         VARCHAR(30),                            -- NULL разрешён (часть 3: 2 покупателя без телефона)
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- addresses — адреса доставки (1:N к customers)
-- ============================================================================
CREATE TABLE addresses (
    id          SERIAL PRIMARY KEY,
    customer_id INT         NOT NULL
                REFERENCES customers(id) ON DELETE CASCADE,   -- адрес без покупателя не нужен
    city        VARCHAR(100) NOT NULL,
    street      VARCHAR(200) NOT NULL,
    postal_code VARCHAR(20),                                  -- в 2.4 меняется на VARCHAR(10)
    is_default  BOOLEAN      NOT NULL DEFAULT FALSE
);

-- ============================================================================
-- brands — бренды техники
-- ============================================================================
CREATE TABLE brands (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL UNIQUE,
    country         VARCHAR(100),
    warranty_months INT
);

-- ============================================================================
-- categories — категории (self-reference: Крупная/Мелкая -> подкатегории)
-- ============================================================================
CREATE TABLE categories (
    id        SERIAL PRIMARY KEY,
    name      VARCHAR(100) NOT NULL,
    parent_id INT REFERENCES categories(id) ON DELETE SET NULL  -- корень = parent_id NULL
);

-- ============================================================================
-- suppliers — поставщики
-- ============================================================================
CREATE TABLE suppliers (
    id      SERIAL PRIMARY KEY,
    name    VARCHAR(200) NOT NULL,
    email   VARCHAR(255),
    country VARCHAR(100)                                   -- в 2.4 этот столбец удаляется
);

-- ============================================================================
-- products — товары (модели техники)
-- brand_id обязателен (часть 5), category_id может быть NULL (часть 3: 2 товара без категории)
-- ============================================================================
CREATE TABLE products (
    id           SERIAL PRIMARY KEY,
    name         VARCHAR(200)  NOT NULL,
    model        VARCHAR(100),
    description  TEXT,
    price        DECIMAL(10,2) NOT NULL CHECK (price > 0),      -- деньги = DECIMAL, не FLOAT (1.5)
    stock        INT           NOT NULL DEFAULT 0 CHECK (stock >= 0),
    power_watt   INT,
    energy_class VARCHAR(4) CHECK (energy_class IN ('A++','A+','A','B','C')),
    brand_id     INT NOT NULL REFERENCES brands(id)     ON DELETE RESTRICT,  -- бренд с товарами не удалить
    category_id  INT          REFERENCES categories(id) ON DELETE SET NULL,  -- категория удаляется -> товар без категории
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- orders — заказы
-- ============================================================================
CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,  -- решение 1.3 (см. README)
    address_id  INT          REFERENCES addresses(id) ON DELETE SET NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'new'
                CHECK (status IN ('new','paid','shipped','delivered','cancelled')),
    total       DECIMAL(10,2) NOT NULL DEFAULT 0,
    created_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- order_items — позиции заказа (реализует N:M между orders и products)
-- ============================================================================
CREATE TABLE order_items (
    id         SERIAL PRIMARY KEY,
    order_id   INT NOT NULL REFERENCES orders(id)   ON DELETE CASCADE,   -- удалили заказ -> ушли позиции
    product_id INT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,  -- товар из заказа не удалить (история)
    quantity   INT           NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL                                     -- цена на момент заказа (1.4)
);

-- ============================================================================
-- payments — платежи (1:N к orders: один заказ с двумя платежами в части 3)
-- ============================================================================
CREATE TABLE payments (
    id       SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    amount   DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    method   VARCHAR(50)  NOT NULL,
    status   VARCHAR(30)  NOT NULL,
    paid_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP   -- TIMESTAMP по 2.5; про TIMESTAMPTZ — в README
);

-- ============================================================================
-- reviews — отзывы (один отзыв на товар от одного покупателя)
-- ============================================================================
CREATE TABLE reviews (
    id          SERIAL PRIMARY KEY,
    product_id  INT NOT NULL REFERENCES products(id)  ON DELETE CASCADE,
    customer_id INT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    rating      INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment     TEXT,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (product_id, customer_id)                          -- один отзыв на товар от покупателя
);

-- ============================================================================
-- product_suppliers — поставки товара (составной PK, N:M товары<->поставщики)
-- ============================================================================
CREATE TABLE product_suppliers (
    product_id   INT NOT NULL REFERENCES products(id)  ON DELETE CASCADE,
    supplier_id  INT NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
    supply_price DECIMAL(10,2) NOT NULL CHECK (supply_price > 0),
    PRIMARY KEY (product_id, supplier_id)                     -- составной первичный ключ
);

-- ============================================================================
-- Индексы (часть 5 — там же EXPLAIN. Здесь только базовые на FK/поиск)
-- PRIMARY KEY и UNIQUE индексы Postgres создаёт автоматически.
-- ============================================================================
CREATE INDEX idx_addresses_customer       ON addresses(customer_id);
CREATE INDEX idx_products_brand           ON products(brand_id);
CREATE INDEX idx_products_category        ON products(category_id);
CREATE INDEX idx_orders_customer          ON orders(customer_id);
CREATE INDEX idx_order_items_order_product ON order_items(order_id, product_id); -- составной
CREATE INDEX idx_reviews_product          ON reviews(product_id);
