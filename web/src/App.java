import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import org.postgresql.util.PSQLException;
import org.postgresql.util.ServerErrorMessage;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.math.BigDecimal;
import java.net.InetSocketAddress;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.Executors;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * ТехноМир — демо-сайт поверх базы shop (Docker, порт 5433).
 *
 * Всё, что делает пользователь на сайте, выполняется настоящими SQL-командами
 * в той же базе, которую вы смотрите в DBeaver. Каждый ответ API возвращает
 * журнал выполненных команд — сайт показывает его внизу страницы.
 *
 * Запуск: ./run.sh  →  http://localhost:8088
 */
public final class App {

    // ===================================================================== маршруты

    interface Handler {
        Object handle(Sql db, Req r) throws Exception;
    }

    record Route(String method, Pattern pattern, Handler handler) { }

    static final List<Route> ROUTES = new ArrayList<>();

    static void route(String method, String regex, Handler h) {
        ROUTES.add(new Route(method, Pattern.compile("^" + regex + "$"), h));
    }

    /** Ошибка, которую видит пользователь (не ошибка базы). */
    static final class UserError extends RuntimeException {
        final int status;
        UserError(int status, String message) { super(message); this.status = status; }
    }

    static UserError bad(String message) { return new UserError(400, message); }

    public static void main(String[] args) throws Exception {
        int port = Integer.parseInt(Sql.env("PORT", "8088"));
        Path publicDir = Path.of(Sql.env("PUBLIC_DIR", "public")).toAbsolutePath();

        registerRoutes();

        if (portBusy(port)) {
            System.out.println();
            System.out.println("  Порт " + port + " уже занят другой программой (например, Spring-проектом из IntelliJ).");
            System.out.println("  Остановите её или запустите сайт на другом порту:  PORT=8099 ./web/run.sh");
            System.out.println();
            System.exit(1);
        }
        HttpServer server;
        try {
            server = HttpServer.create(new InetSocketAddress("127.0.0.1", port), 0);
        } catch (java.net.BindException e) {
            System.out.println("  Порт " + port + " занят. Запустите на другом:  PORT=8099 ./web/run.sh");
            System.exit(1);
            return;
        }
        prepareDatabase();
        server.setExecutor(Executors.newFixedThreadPool(8));
        server.createContext("/api/", App::api);
        server.createContext("/", ex -> serveStatic(ex, publicDir));
        server.start();

        System.out.println();
        System.out.println("  ТехноМир запущен:  http://localhost:" + port);
        System.out.println("  База:              " + Sql.url + " (пользователь " + Sql.user + ")");
        System.out.println("  Остановить:        Ctrl+C");
        System.out.println();
    }

    /** Отвечает ли кто-то на localhost:port — по IPv4 или IPv6 (Spring слушает оба). */
    static boolean portBusy(int port) {
        for (String host : new String[]{"127.0.0.1", "::1"}) {
            try (java.net.Socket s = new java.net.Socket()) {
                s.connect(new InetSocketAddress(host, port), 300);
                return true;
            } catch (IOException ignored) {
                // свободно
            }
        }
        return false;
    }

    /**
     * Сайт опирается на view и функцию из части 7. Если 07_views_procedures.sql
     * ещё не выполнялся после пересоздания базы, создаём их здесь — тем же
     * текстом, что в файле. Если они уже есть, ничего не трогаем.
     */
    static void prepareDatabase() {
        try (Sql db = new Sql()) {
            Map<String, Object> st = db.one("""
                SELECT to_regclass('public.v_order_summary') IS NOT NULL AS has_summary,
                       to_regclass('public.v_product_stats') IS NOT NULL AS has_stats,
                       EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'place_order') AS has_fn
                """);
            if (!(Boolean) st.get("has_summary")) { db.exec(Ddl.V_ORDER_SUMMARY); System.out.println("  создан view v_order_summary (часть 7.1)"); }
            if (!(Boolean) st.get("has_stats"))   { db.exec(Ddl.V_PRODUCT_STATS); System.out.println("  создан view v_product_stats (часть 7.1)"); }
            if (!(Boolean) st.get("has_fn"))      { db.exec(Ddl.PLACE_ORDER);     System.out.println("  создана функция place_order (часть 7.2)"); }
        } catch (SQLException e) {
            System.out.println();
            System.out.println("  Нет подключения к базе: " + e.getMessage());
            System.out.println("  Запустите Docker Desktop и выполните в папке проекта: docker compose up -d");
            System.out.println("  Сайт всё равно запустится и подключится, когда база появится.");
        }
    }

    static void registerRoutes() {

        // ---- общее ---------------------------------------------------------------

        route("GET", "/api/status", (db, r) -> {
            Map<String, Object> s = db.one("""
                SELECT (SELECT COUNT(*) FROM products) AS products,
                       (SELECT COUNT(*) FROM orders) AS orders,
                       (SELECT COUNT(*) FROM order_items) AS order_items,
                       (SELECT COUNT(*) FROM payments) AS payments,
                       (SELECT COUNT(*) FROM reviews) AS reviews,
                       current_database() AS db,
                       pg_backend_pid() AS pid
                """);
            s.put("url", Sql.url.replace("jdbc:postgresql://", ""));
            return s;
        });

        route("GET", "/api/meta", (db, r) -> {
            Map<String, Object> m = new LinkedHashMap<>();
            // 9.4: рекурсивный CTE — дерево категорий с уровнем вложенности
            m.put("categories", db.query("""
                WITH RECURSIVE tree AS (
                    SELECT id, name, parent_id, 1 AS level, name::text AS path
                    FROM categories WHERE parent_id IS NULL
                    UNION ALL
                    SELECT c.id, c.name, c.parent_id, t.level + 1, t.path || ' / ' || c.name
                    FROM categories c JOIN tree t ON c.parent_id = t.id
                )
                SELECT t.id, t.name, t.parent_id, t.level,
                       (SELECT COUNT(*) FROM products p
                        WHERE p.category_id = t.id AND p.model IS DISTINCT FROM 'BULK') AS cnt
                FROM tree t
                ORDER BY t.path
                """));
            m.put("uncategorized", db.one(
                "SELECT COUNT(*) AS cnt FROM products WHERE category_id IS NULL AND model IS DISTINCT FROM 'BULK'").get("cnt"));
            m.put("brands", db.query("""
                SELECT b.id, b.name, b.country, b.warranty_months, COUNT(p.id) AS cnt
                FROM brands b
                LEFT JOIN products p ON p.brand_id = b.id AND p.model IS DISTINCT FROM 'BULK'
                GROUP BY b.id
                ORDER BY b.name
                """));
            m.put("customers", db.query("SELECT id, name, email FROM customers ORDER BY id"));
            return m;
        });

        // ---- каталог ---------------------------------------------------------------

        route("GET", "/api/products", (db, r) -> {
            List<Object> params = new ArrayList<>();
            String with = "";
            StringBuilder where = new StringBuilder("WHERE p.model IS DISTINCT FROM 'BULK'");

            String category = r.q("category");
            if ("none".equals(category)) {
                where.append("\n  AND p.category_id IS NULL");
            } else if (category != null && !category.isBlank()) {
                // категория вместе со всеми подкатегориями
                with = """
                    WITH RECURSIVE sub AS (
                        SELECT id FROM categories WHERE id = ?
                        UNION ALL
                        SELECT c.id FROM categories c JOIN sub ON c.parent_id = sub.id
                    )
                    """;
                params.add(toInt(category));
                where.append("\n  AND p.category_id IN (SELECT id FROM sub)");
            }
            List<Integer> brands = intList(r.q("brands"));
            if (!brands.isEmpty()) {
                where.append("\n  AND p.brand_id IN (").append(placeholders(brands.size())).append(")");
                params.addAll(brands);
            }
            List<String> energy = strList(r.q("energy"));
            if (!energy.isEmpty()) {
                where.append("\n  AND p.energy_class IN (").append(placeholders(energy.size())).append(")");
                params.addAll(energy);
            }
            String q = r.q("q");
            if (q != null && !q.isBlank()) {
                // ввод пользователя — только параметром, никогда не склеиваем в SQL (часть 8)
                where.append("\n  AND (p.name ILIKE ? OR p.model ILIKE ? OR b.name ILIKE ?)");
                String like = "%" + q.strip() + "%";
                params.add(like); params.add(like); params.add(like);
            }
            if ("1".equals(r.q("instock"))) where.append("\n  AND p.stock > 0");

            // сортировка — только из белого списка, не из строки запроса
            String order = switch (String.valueOf(r.q("sort"))) {
                case "price_asc"  -> "p.price ASC, p.id";
                case "price_desc" -> "p.price DESC, p.id";
                case "rating"     -> "COALESCE(s.avg_rating, 0) DESC, p.id";
                case "new"        -> "p.id DESC";
                default           -> "COALESCE(s.sold_qty, 0) DESC, p.id";
            };

            String sql = with + """
                SELECT p.id, p.name, p.model, p.price, p.stock, p.energy_class, p.power_watt,
                       p.category_id, COALESCE(c.name, 'Без категории') AS category,
                       c.parent_id AS category_parent, b.name AS brand,
                       s.avg_rating, s.sold_qty,
                       (SELECT COUNT(*) FROM reviews rv WHERE rv.product_id = p.id) AS reviews_cnt
                FROM products p
                JOIN brands b ON b.id = p.brand_id
                LEFT JOIN categories c ON c.id = p.category_id
                LEFT JOIN v_product_stats s ON s.product_id = p.id
                """ + where + "\nORDER BY " + order;
            return db.query(sql, params.toArray());
        });

        route("GET", "/api/products/(\\d+)", (db, r) -> {
            int id = r.id(1);
            Map<String, Object> p = db.one("""
                SELECT p.id, p.name, p.model, p.description, p.price, p.stock, p.power_watt,
                       p.energy_class, p.sku, p.category_id, c.parent_id AS category_parent,
                       b.name AS brand, b.country AS brand_country, b.warranty_months,
                       COALESCE(c.name, 'Без категории') AS category, pc.name AS parent_category,
                       s.avg_rating, s.sold_qty
                FROM products p
                JOIN brands b ON b.id = p.brand_id
                LEFT JOIN categories c  ON c.id = p.category_id
                LEFT JOIN categories pc ON pc.id = c.parent_id
                LEFT JOIN v_product_stats s ON s.product_id = p.id
                WHERE p.id = ?
                """, id);
            if (p == null) throw new UserError(404, "Товар " + id + " не найден — возможно, его удалили в управлении.");
            p.put("suppliers", db.query("""
                SELECT s.id, s.name, ps.supply_price
                FROM product_suppliers ps
                JOIN suppliers s ON s.id = ps.supplier_id
                WHERE ps.product_id = ?
                ORDER BY ps.supply_price
                """, id));
            p.put("reviews", db.query("""
                SELECT r.id, r.rating, r.comment, r.created_at, r.customer_id, c.name AS customer
                FROM reviews r
                JOIN customers c ON c.id = r.customer_id
                WHERE r.product_id = ?
                ORDER BY r.created_at DESC
                """, id));
            return p;
        });

        route("POST", "/api/reviews", (db, r) -> {
            int productId = r.bodyInt("productId");
            int customerId = r.bodyInt("customerId");
            int rating = r.bodyInt("rating");
            String comment = r.bodyStr("comment");
            if (comment != null && comment.isBlank()) comment = null;
            return db.one("""
                INSERT INTO reviews (product_id, customer_id, rating, comment)
                VALUES (?, ?, ?, ?)
                RETURNING id
                """, productId, customerId, rating, comment);
        });

        // ---- покупатель ------------------------------------------------------------

        route("GET", "/api/customers/(\\d+)/addresses", (db, r) -> db.query("""
            SELECT id, city, street, postal_code, is_default
            FROM addresses
            WHERE customer_id = ?
            ORDER BY is_default DESC, id
            """, r.id(1)));

        route("GET", "/api/customers/(\\d+)/orders", (db, r) -> {
            int cid = r.id(1);
            List<Map<String, Object>> orders = db.query("""
                SELECT o.id, o.status, o.total, o.created_at, a.city, a.street,
                       COALESCE((SELECT SUM(amount) FROM payments pm
                                 WHERE pm.order_id = o.id AND pm.status = 'completed'), 0) AS paid,
                       (SELECT string_agg(DISTINCT pm.method, ', ') FROM payments pm
                        WHERE pm.order_id = o.id) AS methods
                FROM orders o
                LEFT JOIN addresses a ON a.id = o.address_id
                WHERE o.customer_id = ?
                ORDER BY o.created_at DESC, o.id DESC
                """, cid);
            List<Map<String, Object>> items = db.query("""
                SELECT oi.order_id, oi.product_id, p.name, p.model, oi.quantity, oi.unit_price,
                       p.category_id, c.parent_id AS category_parent
                FROM order_items oi
                JOIN orders o   ON o.id = oi.order_id
                JOIN products p ON p.id = oi.product_id
                LEFT JOIN categories c ON c.id = p.category_id
                WHERE o.customer_id = ?
                ORDER BY oi.id
                """, cid);
            for (Map<String, Object> o : orders) {
                List<Map<String, Object>> mine = new ArrayList<>();
                for (Map<String, Object> it : items) {
                    if (it.get("order_id").equals(o.get("id"))) mine.add(it);
                }
                o.put("items", mine);
            }
            return orders;
        });

        // ---- оформление заказа: явная транзакция (часть 6) --------------------------

        route("POST", "/api/orders", (db, r) -> {
            int customerId = r.bodyInt("customerId");
            int addressId = r.bodyInt("addressId");
            String payment = r.bodyStr("payment");
            String promo = r.bodyStr("promo");
            if (!Set.of("card", "sbp", "cash").contains(payment)) throw bad("Выберите способ оплаты.");

            List<int[]> items = new ArrayList<>();
            for (Object o : r.bodyList("items")) {
                Map<?, ?> m = (Map<?, ?>) o;
                int pid = toInt(m.get("productId"));
                int qty = toInt(m.get("qty"));
                if (qty <= 0) throw bad("Количество должно быть больше нуля.");
                items.add(new int[]{pid, qty});
            }
            if (items.isEmpty()) throw bad("Корзина пуста — добавьте товар из каталога.");
            BigDecimal discount = BigDecimal.ZERO;
            if (promo != null && !promo.isBlank()) {
                String code = promo.strip().toUpperCase();
                if (code.equals("ТЕХНО1000") || code.equals("TECHNO1000")) discount = new BigDecimal("1000.00");
                else throw bad("Промокод «" + promo.strip() + "» не найден. Для демо есть ТЕХНО1000.");
            }
            // 6.6: строки товаров блокируем всегда по возрастанию id — так два заказа не попадут в deadlock
            items.sort(Comparator.comparingInt(a -> a[0]));

            String current = null;
            db.begin();
            try {
                if (db.one("SELECT id FROM addresses WHERE id = ? AND customer_id = ?", addressId, customerId) == null) {
                    throw bad("Этот адрес принадлежит другому покупателю. Выберите адрес из списка.");
                }
                int orderId = (Integer) db.one("""
                    INSERT INTO orders (customer_id, address_id, status)
                    VALUES (?, ?, 'new')
                    RETURNING id
                    """, customerId, addressId).get("id");

                for (int[] it : items) {
                    Map<String, Object> p = db.one(
                        "SELECT name, price, stock FROM products WHERE id = ? FOR UPDATE", it[0]);
                    if (p == null) throw bad("Товар " + it[0] + " больше не продаётся.");
                    current = p.get("name") + "»: на складе " + p.get("stock") + ", в заказе " + it[1];
                    db.update("""
                        INSERT INTO order_items (order_id, product_id, quantity, unit_price)
                        VALUES (?, ?, ?, ?)
                        """, orderId, it[0], it[1], p.get("price"));
                    // если остатка не хватит, CHECK (stock >= 0) отклонит UPDATE
                    db.update("UPDATE products SET stock = stock - ? WHERE id = ?", it[1], it[0]);
                }
                current = null;
                db.update("""
                    UPDATE orders
                    SET total = (SELECT SUM(quantity * unit_price) FROM order_items WHERE order_id = ?) - ?
                    WHERE id = ?
                    """, orderId, discount, orderId);

                if (!payment.equals("cash")) {
                    db.update("""
                        INSERT INTO payments (order_id, amount, method, status)
                        SELECT id, total, ?, 'completed' FROM orders WHERE id = ?
                        """, payment, orderId);
                    db.update("UPDATE orders SET status = 'paid' WHERE id = ?", orderId);
                }
                Map<String, Object> res = db.one("SELECT id, status, total FROM orders WHERE id = ?", orderId);
                db.commit();
                return res;
            } catch (PSQLException e) {
                db.rollbackQuietly();
                if (current != null && "products_stock_check".equals(constraint(e))) {
                    throw new UserError(409, "Не хватает товара «" + current
                        + ". CHECK (stock >= 0) отклонил списание, и ROLLBACK отменил всю транзакцию — заказ не создан.");
                }
                throw e;
            }
        });

        // ---- «Купить в 1 клик»: функция place_order из части 7.2 -----------------------

        route("POST", "/api/orders/quick", (db, r) -> {
            int customerId = r.bodyInt("customerId");
            int productId = r.bodyInt("productId");
            int qty = r.bodyInt("qty");
            db.begin();
            int orderId = (Integer) db.one("SELECT place_order(?, ?, ?) AS order_id", customerId, productId, qty).get("order_id");
            // place_order не знает про адрес — ставим адрес по умолчанию в той же транзакции
            db.update("""
                UPDATE orders
                SET address_id = (SELECT id FROM addresses WHERE customer_id = ?
                                  ORDER BY is_default DESC, id LIMIT 1)
                WHERE id = ?
                """, customerId, orderId);
            Map<String, Object> res = db.one("SELECT id, status, total FROM orders WHERE id = ?", orderId);
            db.commit();
            return res;
        });

        route("POST", "/api/orders/(\\d+)/cancel", (db, r) -> {
            int orderId = r.id(1);
            int customerId = r.bodyInt("customerId");
            db.begin();
            Map<String, Object> o = db.one(
                "SELECT status FROM orders WHERE id = ? AND customer_id = ? FOR UPDATE", orderId, customerId);
            if (o == null) throw new UserError(404, "Заказ " + orderId + " не найден у этого покупателя.");
            String status = (String) o.get("status");
            if (!status.equals("new") && !status.equals("paid")) {
                throw new UserError(409, "Заказ " + orderId + " уже в статусе «" + status + "» — отменить можно только новый или оплаченный.");
            }
            // товар возвращается на склад, платёж помечается возвращённым
            db.update("""
                UPDATE products p
                SET stock = p.stock + oi.quantity
                FROM order_items oi
                WHERE oi.order_id = ? AND p.id = oi.product_id
                """, orderId);
            db.update("UPDATE payments SET status = 'refunded' WHERE order_id = ?", orderId);
            db.update("UPDATE orders SET status = 'cancelled' WHERE id = ?", orderId);
            db.commit();
            return Map.of("id", orderId, "status", "cancelled");
        });

        // ---- управление ------------------------------------------------------------

        route("GET", "/api/admin/orders", (db, r) -> {
            String status = r.q("status");
            if (status != null && !status.isBlank()) {
                return db.query("""
                    SELECT v.order_id, v.customer_name, v.items_cnt, v.total, v.status, v.created_at
                    FROM v_order_summary v
                    WHERE v.status = ?
                    ORDER BY v.order_id DESC
                    """, status);
            }
            return db.query("""
                SELECT v.order_id, v.customer_name, v.items_cnt, v.total, v.status, v.created_at
                FROM v_order_summary v
                ORDER BY v.order_id DESC
                """);
        });

        route("POST", "/api/admin/orders/(\\d+)/status", (db, r) -> {
            int n = db.update("UPDATE orders SET status = ? WHERE id = ?", r.bodyStr("status"), r.id(1));
            if (n == 0) throw new UserError(404, "Заказ " + r.id(1) + " не найден.");
            return Map.of("id", r.id(1), "status", r.bodyStr("status"));
        });

        route("POST", "/api/admin/orders/(\\d+)/delete", (db, r) -> {
            int id = r.id(1);
            db.begin();
            Map<String, Object> before = db.one("""
                SELECT (SELECT COUNT(*) FROM order_items WHERE order_id = ?) AS items,
                       (SELECT COUNT(*) FROM payments    WHERE order_id = ?) AS payments
                """, id, id);
            int n = db.update("DELETE FROM orders WHERE id = ?", id);
            if (n == 0) throw new UserError(404, "Заказ " + id + " уже удалён.");
            Map<String, Object> after = db.one("""
                SELECT (SELECT COUNT(*) FROM order_items WHERE order_id = ?) AS items,
                       (SELECT COUNT(*) FROM payments    WHERE order_id = ?) AS payments
                """, id, id);
            db.commit();
            return Map.of("id", id, "items", before.get("items"), "payments", before.get("payments"),
                          "itemsAfter", after.get("items"), "paymentsAfter", after.get("payments"));
        });

        route("GET", "/api/admin/products", (db, r) -> db.query("""
            SELECT s.product_id AS id, s.product_name AS name, s.model, s.category, b.name AS brand,
                   s.price, s.stock, s.sold_qty, s.avg_rating, p.energy_class
            FROM v_product_stats s
            JOIN products p ON p.id = s.product_id
            JOIN brands b   ON b.id = p.brand_id
            WHERE p.model IS DISTINCT FROM 'BULK'
            ORDER BY s.product_id
            """));

        route("POST", "/api/admin/products", (db, r) -> {
            String name = r.bodyStr("name");
            if (name == null || name.isBlank()) throw bad("Укажите название товара.");
            String energy = r.bodyStr("energyClass");
            Object category = r.body.get("categoryId");
            return db.one("""
                INSERT INTO products (name, model, price, stock, energy_class, brand_id, category_id)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                RETURNING id
                """, name.strip(), blankToNull(r.bodyStr("model")), r.bodyDecimal("price"), r.bodyInt("stock"),
                blankToNull(energy), r.bodyInt("brandId"),
                category == null || "".equals(category) ? null : toInt(category));
        });

        route("POST", "/api/admin/products/(\\d+)", (db, r) -> {
            int n = db.update("UPDATE products SET price = ?, stock = ? WHERE id = ?",
                r.bodyDecimal("price"), r.bodyInt("stock"), r.id(1));
            if (n == 0) throw new UserError(404, "Товар " + r.id(1) + " не найден.");
            return Map.of("id", r.id(1));
        });

        route("POST", "/api/admin/products/(\\d+)/delete", (db, r) -> {
            int n = db.update("DELETE FROM products WHERE id = ?", r.id(1));
            if (n == 0) throw new UserError(404, "Товар " + r.id(1) + " уже удалён.");
            return Map.of("id", r.id(1));
        });

        // 3.2: число строк в каждой таблице
        route("GET", "/api/admin/counts", (db, r) -> db.query("""
            SELECT 'customers' AS tbl, COUNT(*) AS cnt FROM customers
            UNION ALL SELECT 'addresses', COUNT(*) FROM addresses
            UNION ALL SELECT 'brands', COUNT(*) FROM brands
            UNION ALL SELECT 'categories', COUNT(*) FROM categories
            UNION ALL SELECT 'suppliers', COUNT(*) FROM suppliers
            UNION ALL SELECT 'products', COUNT(*) FROM products
            UNION ALL SELECT 'product_suppliers', COUNT(*) FROM product_suppliers
            UNION ALL SELECT 'orders', COUNT(*) FROM orders
            UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
            UNION ALL SELECT 'payments', COUNT(*) FROM payments
            UNION ALL SELECT 'reviews', COUNT(*) FROM reviews
            """));
    }

    // ===================================================================== ошибки базы

    static String constraint(PSQLException e) {
        ServerErrorMessage m = e.getServerErrorMessage();
        return m == null ? null : m.getConstraint();
    }

    /** Переводит ошибку PostgreSQL в понятное объяснение: что сработало в схеме и почему. */
    static String explain(SQLException e) {
        String state = e.getSQLState() == null ? "" : e.getSQLState();
        String c = e instanceof PSQLException pe ? constraint(pe) : null;
        String server = e instanceof PSQLException pe && pe.getServerErrorMessage() != null
            ? pe.getServerErrorMessage().getMessage() : e.getMessage();
        if (c != null) {
            switch (c) {
                case "products_stock_check":
                    return "Остаток не может быть меньше нуля — CHECK (stock >= 0) отклонил команду.";
                case "products_price_check":
                    return "Цена должна быть больше нуля — CHECK (price > 0) отклонил команду.";
                case "reviews_product_id_customer_id_key":
                    return "Этот покупатель уже оставил отзыв на товар — UNIQUE (product_id, customer_id) не даёт написать второй.";
                case "reviews_rating_check":
                    return "Оценка должна быть от 1 до 5 — CHECK (rating BETWEEN 1 AND 5).";
                case "order_items_product_id_fkey":
                    return "Товар есть в заказах, а ON DELETE RESTRICT запрещает удалять товар с историей продаж. Удалить можно товар, который ни разу не заказывали.";
                case "orders_status_check":
                    return "Такого статуса нет — CHECK разрешает только new, paid, shipped, delivered, cancelled.";
                case "products_energy_class_check":
                    return "Класс энергоэффективности — только A++, A+, A, B или C.";
                case "uq_products_sku":
                    return "Такой артикул уже есть — UNIQUE (sku).";
                case "products_brand_id_fkey":
                    return "Такого бренда нет — внешний ключ brand_id ссылается на brands(id).";
                default:
                    break;
            }
        }
        if ("P0001".equals(state)) return server + " — RAISE EXCEPTION в place_order откатил заказ и позицию.";
        if ("40P01".equals(state)) return "Deadlock: PostgreSQL нашёл взаимную блокировку и откатил эту транзакцию.";
        if (state.startsWith("08")) return "Нет подключения к базе. Запустите Docker Desktop и выполните docker compose up -d.";
        if ("42883".equals(state) || "42P01".equals(state)) {
            return "В базе нет нужного объекта (" + server + "). Выполните 07_views_procedures.sql или перезапустите сайт — он создаст view и функцию сам.";
        }
        return server;
    }

    // ===================================================================== HTTP

    static void api(HttpExchange ex) throws IOException {
        String method = ex.getRequestMethod();
        String path = ex.getRequestURI().getPath();
        Map<String, Object> out = new LinkedHashMap<>();
        int code = 200;

        Route found = null;
        Matcher matcher = null;
        for (Route rt : ROUTES) {
            Matcher m = rt.pattern().matcher(path);
            if (rt.method().equals(method) && m.matches()) { found = rt; matcher = m; break; }
        }
        if (found == null) {
            send(ex, 404, Json.write(Map.of("error", "Нет такого адреса: " + method + " " + path)));
            return;
        }

        Sql db = null;
        try {
            Req req = new Req(ex, matcher);
            db = new Sql();
            out.put("data", found.handler().handle(db, req));
        } catch (UserError e) {
            code = e.status;
            out.put("error", e.getMessage());
        } catch (SQLException e) {
            code = e.getSQLState() != null && e.getSQLState().startsWith("08") ? 503 : 409;
            if (db != null) db.rollbackQuietly();
            out.put("error", explain(e));
            out.put("sqlstate", e.getSQLState());
            out.put("detail", e instanceof PSQLException pe && pe.getServerErrorMessage() != null
                ? pe.getServerErrorMessage().getMessage() : e.getMessage());
        } catch (IllegalArgumentException | ClassCastException | NullPointerException e) {
            code = 400;
            out.put("error", "Неверные данные запроса: " + e.getMessage());
        } catch (Exception e) {
            code = 500;
            out.put("error", "Ошибка сервера: " + e);
            e.printStackTrace();
        } finally {
            if (db != null) {
                db.close();
                out.put("sql", db.log);
            }
        }
        send(ex, code, Json.write(out));
    }

    static void serveStatic(HttpExchange ex, Path dir) throws IOException {
        String p = ex.getRequestURI().getPath();
        if (p.equals("/")) p = "/index.html";
        Path file = dir.resolve(p.substring(1)).normalize();
        if (!file.startsWith(dir) || !Files.isRegularFile(file)) {
            byte[] b = "Не найдено".getBytes(StandardCharsets.UTF_8);
            ex.getResponseHeaders().set("Content-Type", "text/plain; charset=utf-8");
            ex.sendResponseHeaders(404, b.length);
            try (OutputStream os = ex.getResponseBody()) { os.write(b); }
            return;
        }
        String type = p.endsWith(".html") ? "text/html; charset=utf-8"
            : p.endsWith(".js") ? "text/javascript; charset=utf-8"
            : p.endsWith(".css") ? "text/css; charset=utf-8"
            : p.endsWith(".svg") ? "image/svg+xml" : "application/octet-stream";
        byte[] b = Files.readAllBytes(file);
        ex.getResponseHeaders().set("Content-Type", type);
        ex.getResponseHeaders().set("Cache-Control", "no-store");
        ex.sendResponseHeaders(200, b.length);
        try (OutputStream os = ex.getResponseBody()) { os.write(b); }
    }

    static void send(HttpExchange ex, int code, String json) throws IOException {
        byte[] b = json.getBytes(StandardCharsets.UTF_8);
        ex.getResponseHeaders().set("Content-Type", "application/json; charset=utf-8");
        ex.getResponseHeaders().set("Cache-Control", "no-store");
        ex.sendResponseHeaders(code, b.length);
        try (OutputStream os = ex.getResponseBody()) { os.write(b); }
    }

    // ===================================================================== запрос

    static final class Req {
        final Map<String, String> query = new LinkedHashMap<>();
        final Map<String, Object> body;
        final Matcher path;

        @SuppressWarnings("unchecked")
        Req(HttpExchange ex, Matcher path) throws IOException {
            this.path = path;
            String raw = ex.getRequestURI().getRawQuery();
            if (raw != null) {
                for (String pair : raw.split("&")) {
                    int i = pair.indexOf('=');
                    if (i <= 0) continue;
                    query.put(URLDecoder.decode(pair.substring(0, i), StandardCharsets.UTF_8),
                              URLDecoder.decode(pair.substring(i + 1), StandardCharsets.UTF_8));
                }
            }
            try (InputStream in = ex.getRequestBody()) {
                Object parsed = Json.parse(new String(in.readAllBytes(), StandardCharsets.UTF_8));
                body = parsed instanceof Map ? (Map<String, Object>) parsed : new LinkedHashMap<>();
            }
        }

        String q(String k) { return query.get(k); }
        int id(int group) { return Integer.parseInt(path.group(group)); }

        int bodyInt(String k) {
            Object v = body.get(k);
            if (v == null || "".equals(v)) throw bad("Не заполнено поле «" + k + "».");
            return toInt(v);
        }

        BigDecimal bodyDecimal(String k) {
            Object v = body.get(k);
            if (v == null || "".equals(v)) throw bad("Не заполнено поле «" + k + "».");
            try {
                return new BigDecimal(String.valueOf(v).replace(" ", "").replace(',', '.'));
            } catch (NumberFormatException e) {
                throw bad("Поле «" + k + "» должно быть числом.");
            }
        }

        String bodyStr(String k) {
            Object v = body.get(k);
            return v == null ? null : String.valueOf(v);
        }

        List<?> bodyList(String k) {
            Object v = body.get(k);
            return v instanceof List<?> l ? l : List.of();
        }
    }

    // ===================================================================== мелочи

    static int toInt(Object v) {
        try {
            if (v instanceof BigDecimal d) return d.intValueExact();
            return Integer.parseInt(String.valueOf(v).strip());
        } catch (NumberFormatException | ArithmeticException e) {
            throw bad("Ожидалось целое число, получено «" + v + "».");
        }
    }

    static List<Integer> intList(String s) {
        List<Integer> out = new ArrayList<>();
        if (s == null || s.isBlank()) return out;
        for (String part : s.split(",")) if (!part.isBlank()) out.add(toInt(part));
        return out;
    }

    static List<String> strList(String s) {
        List<String> out = new ArrayList<>();
        if (s == null || s.isBlank()) return out;
        for (String part : s.split(",")) if (!part.isBlank()) out.add(part.strip());
        return out;
    }

    static String placeholders(int n) {
        return String.join(", ", java.util.Collections.nCopies(n, "?"));
    }

    static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.strip();
    }
}
