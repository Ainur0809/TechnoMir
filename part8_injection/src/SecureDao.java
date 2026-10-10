import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

/**
 * ЗАЩИЩЁННЫЙ слой доступа — как надо писать.
 *
 * Те же самые операции, что в {@link VulnerableDao}, но через
 * PreparedStatement с параметрами (?). Драйвер передаёт значения отдельно
 * от текста запроса, поэтому ввод пользователя уже НЕ может стать кодом:
 * он всегда трактуется как данные. Те же атаки против этих методов не
 * срабатывают — это показывает Main.
 */
public class SecureDao {

    // Доп. уровень защиты: валидация формата email (принцип «проверяй ввод»).
    private static final Pattern EMAIL =
            Pattern.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$");

    private final Connection conn;

    public SecureDao(Connection conn) {
        this.conn = conn;
    }

    /** 8.5. Защищённый логин: email и пароль идут как параметры, не как код. */
    public String login(String email, String password) throws SQLException {
        String sql = "SELECT id, name FROM customers "
                + "WHERE email = ? AND password_hash = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, email);
            ps.setString(2, password);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getString("name") : null;
            }
        }
    }

    /** 8.5. Защищённый поиск: искомая строка — это параметр, а не фрагмент SQL. */
    public List<String> searchProducts(String search) throws SQLException {
        String sql = "SELECT name, price FROM products WHERE name LIKE ?";
        List<String> rows = new ArrayList<>();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, "%" + search + "%");   // % добавляем к значению, не к SQL
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    rows.add(rs.getString(1) + " | " + rs.getString(2));
                }
            }
        }
        return rows;
    }

    /** Логин с дополнительной валидацией email до обращения к базе. */
    public String loginWithValidation(String email, String password) throws SQLException {
        if (email == null || !EMAIL.matcher(email).matches()) {
            System.out.println("  [отказ] email не прошёл валидацию формата");
            return null;
        }
        return login(email, password);
    }
}
