import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

/**
 * УЯЗВИМЫЙ слой доступа к данным — как писать НЕ НАДО.
 *
 * Здесь запросы собираются склейкой строк, поэтому ввод пользователя
 * становится частью SQL-кода. Это и есть корень SQL-инъекции. Класс нужен
 * только для того, чтобы на стенде увидеть атаку своими глазами и затем
 * сравнить с {@link SecureDao}. В рабочем коде так делать нельзя.
 */
public class VulnerableDao {

    private final Connection conn;

    public VulnerableDao(Connection conn) {
        this.conn = conn;
    }

    /**
     * 8.1. Логин склейкой строк. Введённые email и пароль вставляются прямо
     * в текст запроса. Метод возвращает имя вошедшего покупателя или null.
     */
    public String login(String email, String password) throws SQLException {
        String sql = "SELECT id, name FROM customers "
                + "WHERE email = '" + email + "' "
                + "AND password_hash = '" + password + "'";
        System.out.println("  [SQL] " + sql);
        try (Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(sql)) {
            if (rs.next()) {
                return rs.getString("name");
            }
            return null;
        }
    }

    /**
     * 8.2. Поиск товаров склейкой строк. Через этот метод подбирается
     * UNION-инъекция: число и типы колонок (text, затем значение) должны
     * совпасть с «name, price».
     */
    public List<String> searchProducts(String search) throws SQLException {
        String sql = "SELECT name, price FROM products "
                + "WHERE name LIKE '%" + search + "%'";
        System.out.println("  [SQL] " + sql);
        List<String> rows = new ArrayList<>();
        try (Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(sql)) {
            while (rs.next()) {
                rows.add(rs.getString(1) + " | " + rs.getString(2));
            }
        }
        return rows;
    }

    /**
     * 8.4. Поле, которое отвечает только «найдено / не найдено»: есть ли
     * покупатель с таким email. Данные наружу не отдаёт, но по ответу
     * true/false можно вытаскивать информацию по одному биту (blind injection).
     */
    public boolean customerExists(String email) throws SQLException {
        String sql = "SELECT 1 FROM customers WHERE email = '" + email + "'";
        System.out.println("  [SQL] " + sql);
        try (Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(sql)) {
            return rs.next();
        }
    }
}
