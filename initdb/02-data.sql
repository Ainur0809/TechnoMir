-- ============================================================================
-- ТехноМир — data.sql (часть 3). Заполняет Человек A.
-- Запускается ПОСЛЕ 01-schema.sql (поэтому префикс 02-).
-- Требования по объёму и обязательным случаям — часть 3.1 задания.
-- Реальные модели техники (Samsung, LG, Bosch, Philips, Xiaomi, Tefal), не "товар 1".
-- ============================================================================

-- Порядок вставки = порядок зависимостей (сначала родители):
-- 1) brands, categories, suppliers, customers
-- 2) addresses, products
-- 3) orders, product_suppliers, reviews
-- 4) order_items, payments

-- TODO (Человек A): наполнить по таблице объёмов из части 3.1
-- brands (6), categories (6, 2 уровня), customers (10), addresses (12),
-- products (25), suppliers (4), product_suppliers (10), orders (20),
-- order_items (40), payments (15), reviews (15).
