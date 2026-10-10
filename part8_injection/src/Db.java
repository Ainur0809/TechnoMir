import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

/**
 * Параметры подключения к учебной базе shop (Docker, порт 5433).
 *
 * ВНИМАНИЕ. Весь код в этом проекте — учебный стенд для части 8 задания.
 * Он показывает, КАК ломается небезопасный код и КАК его чинят, чтобы
 * тестировщик умел находить и закрывать такие дыры. Запускать только на
 * своей локальной учебной базе. Разрушительные сценарии (8.3) — исключительно
 * на копии shop_copy, никогда на боевых данных.
 */
public final class Db {

    static final String URL  = "jdbc:postgresql://localhost:5433/shop";
    static final String USER = "postgres";
    static final String PASS = "postgres";

    private Db() { }

    static Connection connect() throws SQLException {
        return DriverManager.getConnection(URL, USER, PASS);
    }

    static Connection connect(String database) throws SQLException {
        return DriverManager.getConnection(
                "jdbc:postgresql://localhost:5433/" + database, USER, PASS);
    }
}
