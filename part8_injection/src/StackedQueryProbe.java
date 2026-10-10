import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

/**
 * 8.3. Разрушительная (stacked) инъекция — проверка на КОПИИ shop_copy.
 *
 * Запускать ТОЛЬКО на shop_copy: последний шаг реально удаляет таблицу reviews.
 * Перед КАЖДЫМ запуском пересоздавайте shop_copy из дампа shop
 * (см. injection.md, 8.3), иначе reviews уже не будет.
 *
 * Показывает главный вывод 8.3: вера «JDBC сам защищает от нескольких
 * операторов» — ложная. Защищает параметризация, а не драйвер.
 */
public class StackedQueryProbe {

    public static void main(String[] args) throws SQLException {
        try (Connection conn = Db.connect("shop_copy")) {
            String payload = "'; DROP TABLE reviews; --";
            System.out.println("reviews в начале: " + reviewsCount(conn));

            // --- Шаг 1. Параметризованный поиск: payload — это ДАННЫЕ ---------
            System.out.println("\n[1] PreparedStatement (параметр):");
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT name, price FROM products WHERE name LIKE ?")) {
                ps.setString(1, "%" + payload + "%");
                try (ResultSet rs = ps.executeQuery()) {
                    int n = 0;
                    while (rs.next()) {
                        n++;
                    }
                    System.out.println("  выполнился как поиск, найдено товаров: " + n);
                }
            }
            System.out.println("  reviews после PreparedStatement: " + reviewsCount(conn)
                    + "   <- таблица цела, атака не прошла");

            // --- Шаг 2. Склейка строк через обычный Statement ----------------
            // Именно так ломается уязвимый searchProducts. Второй оператор
            // (DROP) выполняется ДО того, как executeQuery бросит ошибку про
            // «несколько ResultSet». То есть драйвер НЕ помешал удалению.
            System.out.println("\n[2] обычный Statement (склейка строк):");
            String sql = "SELECT name, price FROM products WHERE name LIKE '%" + payload + "%'";
            System.out.println("  [SQL] " + sql);
            try (Statement st = conn.createStatement()) {
                st.execute(sql);
                System.out.println("  выполнился без ошибки");
            } catch (SQLException e) {
                System.out.println("  executeQuery/execute бросил: " + firstLine(e.getMessage()));
            }
            System.out.println("  reviews после Statement: " + reviewsCount(conn));

            System.out.println("\nВывод: PostgreSQL JDBC с обычным Statement ВЫПОЛНЯЕТ "
                    + "несколько операторов через ';'. Таблица удалена. "
                    + "Спас бы только PreparedStatement.");
        }
    }

    private static String reviewsCount(Connection conn) {
        try (Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM reviews")) {
            return rs.next() ? rs.getString(1) + " строк" : "?";
        } catch (SQLException e) {
            return "ТАБЛИЦА ОТСУТСТВУЕТ";
        }
    }

    private static String firstLine(String s) {
        int nl = s.indexOf('\n');
        return nl < 0 ? s : s.substring(0, nl);
    }
}
