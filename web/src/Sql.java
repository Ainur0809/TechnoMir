import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Одно подключение к базе на один HTTP-запрос + журнал всех выполненных команд.
 *
 * Каждый запрос идёт через PreparedStatement: текст SQL и параметры передаются
 * в PostgreSQL отдельно (защита из части 8). В журнал попадает и текст с ?,
 * и параметры, и «готовая» строка с подставленными значениями — её можно
 * скопировать на сайте и выполнить в DBeaver.
 */
final class Sql implements AutoCloseable {

    static String url  = env("DB_URL",  "jdbc:postgresql://localhost:5433/shop");
    static String user = env("DB_USER", "postgres");
    static String pass = env("DB_PASS", "postgres");

    final Connection conn;
    final List<Map<String, Object>> log = new ArrayList<>();
    private boolean inTx;

    Sql() throws SQLException {
        conn = DriverManager.getConnection(url, user, pass);
        conn.setAutoCommit(true);
    }

    static String env(String key, String def) {
        String v = System.getenv(key);
        return v == null || v.isBlank() ? def : v;
    }

    // ---------------------------------------------------------------- транзакции

    void begin() throws SQLException {
        conn.setAutoCommit(false);
        inTx = true;
        note("BEGIN;", "tx");
    }

    void commit() throws SQLException {
        conn.commit();
        conn.setAutoCommit(true);
        inTx = false;
        note("COMMIT;", "tx");
    }

    /** Откат, если транзакция открыта. Ошибки самого отката не скрывают исходную. */
    void rollbackQuietly() {
        if (!inTx) return;
        try {
            conn.rollback();
            conn.setAutoCommit(true);
        } catch (SQLException ignored) {
            // соединение всё равно будет закрыто
        }
        inTx = false;
        note("ROLLBACK;", "rollback");
    }

    // ---------------------------------------------------------------- запросы

    List<Map<String, Object>> query(String sql, Object... params) throws SQLException {
        long t0 = System.nanoTime();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            bind(ps, params);
            List<Map<String, Object>> rows = new ArrayList<>();
            try (ResultSet rs = ps.executeQuery()) {
                ResultSetMetaData md = rs.getMetaData();
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    for (int c = 1; c <= md.getColumnCount(); c++) {
                        row.put(md.getColumnLabel(c), rs.getObject(c));
                    }
                    rows.add(row);
                }
            }
            record(sql, params, t0, "строк: " + rows.size(), "ok");
            return rows;
        } catch (SQLException e) {
            record(sql, params, t0, e.getMessage(), "error");
            throw e;
        }
    }

    Map<String, Object> one(String sql, Object... params) throws SQLException {
        List<Map<String, Object>> rows = query(sql, params);
        return rows.isEmpty() ? null : rows.get(0);
    }

    int update(String sql, Object... params) throws SQLException {
        long t0 = System.nanoTime();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            bind(ps, params);
            int n = ps.executeUpdate();
            record(sql, params, t0, "изменено строк: " + n, "ok");
            return n;
        } catch (SQLException e) {
            record(sql, params, t0, e.getMessage(), "error");
            throw e;
        }
    }

    /** Служебные команды без параметров (CREATE OR REPLACE при старте). */
    void exec(String sql) throws SQLException {
        try (Statement st = conn.createStatement()) {
            st.execute(sql);
        }
    }

    private static void bind(PreparedStatement ps, Object[] params) throws SQLException {
        for (int i = 0; i < params.length; i++) {
            ps.setObject(i + 1, params[i]);
        }
    }

    // ---------------------------------------------------------------- журнал

    private void note(String sql, String kind) {
        Map<String, Object> e = new LinkedHashMap<>();
        e.put("sql", sql);
        e.put("kind", kind);
        log.add(e);
    }

    private void record(String sql, Object[] params, long t0, String result, String status) {
        Map<String, Object> e = new LinkedHashMap<>();
        String clean = sql.strip().replaceAll("[ \\t]+\\n", "\n");
        e.put("sql", clean);
        List<Object> ps = new ArrayList<>();
        for (Object p : params) ps.add(p == null ? null : String.valueOf(p));
        e.put("params", ps);
        e.put("inline", inline(clean, params) + ";");
        e.put("ms", Math.round((System.nanoTime() - t0) / 10_000.0) / 100.0);
        e.put("result", result);
        e.put("kind", status);
        log.add(e);
    }

    /** Подставляет параметры вместо ? — только для показа в журнале, не для выполнения. */
    static String inline(String sql, Object[] params) {
        StringBuilder sb = new StringBuilder();
        int p = 0;
        boolean inQuote = false;
        for (int i = 0; i < sql.length(); i++) {
            char c = sql.charAt(i);
            if (c == '\'') inQuote = !inQuote;
            if (c == '?' && !inQuote && p < params.length) {
                Object v = params[p++];
                if (v == null) sb.append("NULL");
                else if (v instanceof Number || v instanceof BigDecimal || v instanceof Boolean) sb.append(v);
                else sb.append('\'').append(String.valueOf(v).replace("'", "''")).append('\'');
            } else {
                sb.append(c);
            }
        }
        return sb.toString();
    }

    @Override
    public void close() {
        rollbackQuietly();
        try {
            conn.close();
        } catch (SQLException ignored) {
            // нечего делать
        }
    }
}
