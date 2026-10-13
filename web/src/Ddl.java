/**
 * View и функция из 07_views_procedures.sql (части 7.1 и 7.2) — тот же текст.
 * App создаёт их при старте, только если их ещё нет в базе.
 */
final class Ddl {

    private Ddl() { }

    static final String V_ORDER_SUMMARY = """
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
        """;

    static final String V_PRODUCT_STATS = """
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
        """;

    static final String PLACE_ORDER = """
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
        """;
}
