import java.sql.Connection;
import java.sql.SQLException;
import java.util.List;

/**
 * Учебный стенд части 8 «SQL Injection».
 *
 * Прогоняет одни и те же атаки сначала против уязвимого кода (видно, как всё
 * ломается), потом против защищённого (видно, что та же атака не проходит).
 * Цель — научить тестировщика распознавать и закрывать такие уязвимости.
 *
 * Запуск — см. part8_injection/run.sh. Работает на локальной базе shop.
 * Разрушительный сценарий 8.3 на основной базе НЕ выполняется (только разбор);
 * выполнять его можно исключительно на копии shop_copy.
 */
public class Main {

    public static void main(String[] args) throws SQLException {
        try (Connection conn = Db.connect()) {
            VulnerableDao vuln = new VulnerableDao(conn);
            SecureDao secure = new SecureDao(conn);

            demo81LoginBypass(vuln);
            demo82UnionTheft(vuln);
            demo83StackedQueries(vuln);
            demo84BlindInjection(vuln);
            demo85Defense(secure);

            System.out.println("\nИтог: защищённый код отбивает те же строки, "
                    + "которые ломали уязвимый. Разница — только в способе "
                    + "передачи ввода (параметры вместо склейки).");
        }
    }

    // ---- 8.1. Обход логина -------------------------------------------------
    private static void demo81LoginBypass(VulnerableDao vuln) throws SQLException {
        header("8.1  Обход логина (' OR '1'='1' --)");

        System.out.println("а) честный вход с неверным паролем:");
        String ok = vuln.login("anna.smirnova@gmail.com", "неправильный");
        System.out.println("  -> вошли как: " + ok + "   (ожидаемо null)\n");

        System.out.println("б) инъекция в поле email, пароль пустой:");
        String injected = vuln.login("' OR '1'='1' --", "");
        System.out.println("  -> вошли как: " + injected
                + "   (первый покупатель из таблицы, пароль не проверялся!)");
        System.out.println("  Почему: условие стало  email = '' OR '1'='1'  — всегда истинно,");
        System.out.println("  а  --  превратил проверку пароля в комментарий.");
    }

    // ---- 8.2. UNION-кража данных ------------------------------------------
    private static void demo82UnionTheft(VulnerableDao vuln) throws SQLException {
        header("8.2  Кража паролей через UNION SELECT");

        System.out.println("а) обычный поиск:");
        print(vuln.searchProducts("Холодильник"));

        System.out.println("\nб) инъекция вытягивает email и хэши паролей в выдачу товаров:");
        // Колонок две: name (text) и price (numeric). Чтобы типы совпали,
        // оба секрета склеиваем в текстовую колонку, а в числовую кладём 0.
        String payload = "' UNION SELECT email || ' / ' || password_hash, 0 FROM customers --";
        List<String> stolen = vuln.searchProducts(payload);
        print(stolen.subList(0, Math.min(5, stolen.size())));
        System.out.println("  ... (всего строк: " + stolen.size() + ")");
        System.out.println("  Товарный поиск отдал учётные данные покупателей.");
    }

    // ---- 8.3. Stacked queries / DROP --------------------------------------
    private static void demo83StackedQueries(VulnerableDao vuln) {
        header("8.3  Разрушительная инъекция (разбор; выполнение — на shop_copy)");
        System.out.println("Payload в поле поиска:");
        System.out.println("    '; DROP TABLE reviews; --");
        System.out.println("даёт текст:");
        System.out.println("    SELECT name, price FROM products WHERE name LIKE '%'; DROP TABLE reviews; --%'");
        System.out.println();
        System.out.println("Частое заблуждение: «JDBC сам не даст выполнить второй оператор».");
        System.out.println("Для PostgreSQL + обычный Statement это НЕВЕРНО — проверено");
        System.out.println("на shop_copy классом StackedQueryProbe: DROP реально удаляет");
        System.out.println("таблицу (executeQuery бросает ошибку про «несколько ResultSet»");
        System.out.println("уже ПОСЛЕ удаления). PreparedStatement ту же строку отбивает.");
        System.out.println();
        System.out.println("Поэтому здесь, на основной базе shop, DROP не запускаем —");
        System.out.println("разрушительную проверку делает только StackedQueryProbe на shop_copy.");
        System.out.println("Разбор «защита и ложное чувство безопасности» — в injection.md, 8.3.");
    }

    // ---- 8.4. Blind injection ---------------------------------------------
    private static void demo84BlindInjection(VulnerableDao vuln) throws SQLException {
        header("8.4  Слепая инъекция (ответ только да/нет)");
        System.out.println("Поле отвечает лишь «найден покупатель или нет». Данные наружу");
        System.out.println("не идут, но по true/false можно вытаскивать их по биту.\n");

        // Базовый true: подставляем всегда истинное условие.
        boolean t = vuln.customerExists("нет-такого@x' OR '1'='1");
        System.out.println("  OR '1'='1'              -> " + t + "  (всегда да)");
        boolean f = vuln.customerExists("нет-такого@x' AND '1'='2");
        System.out.println("  AND '1'='2'             -> " + f + "  (всегда нет)");

        // Проба по одному биту: сколько в таблице покупателей?
        boolean more20 = vuln.customerExists(
                "нет-такого@x' OR (SELECT COUNT(*) FROM customers) > 20 --");
        boolean more50 = vuln.customerExists(
                "нет-такого@x' OR (SELECT COUNT(*) FROM customers) > 50 --");
        System.out.println("  покупателей > 20 ?      -> " + more20);
        System.out.println("  покупателей > 50 ?      -> " + more50);
        System.out.println("  Вывод атакующего: покупателей больше 20, но не больше 50.");
        System.out.println("  Так же по буквам вытаскивают пароль: SUBSTRING(...) = 'a' и т.д.");
    }

    // ---- 8.5. Защита -------------------------------------------------------
    private static void demo85Defense(SecureDao secure) throws SQLException {
        header("8.5  Защита: те же атаки против PreparedStatement");

        System.out.println("а) обход логина 8.1 против защищённого метода:");
        String r1 = secure.login("' OR '1'='1' --", "");
        System.out.println("  -> вошли как: " + r1 + "   (null: строка искалась как email целиком)\n");

        System.out.println("б) UNION-инъекция 8.2 против защищённого поиска:");
        List<String> r2 = secure.searchProducts("' UNION SELECT email, password_hash FROM customers --");
        System.out.println("  -> найдено товаров: " + r2.size()
                + "   (0: искали товар с таким названием, а не выполняли SQL)\n");

        System.out.println("в) честный вход по-прежнему работает:");
        String r3 = secure.login("anna.smirnova@gmail.com", "неважно-какой-на-стенде");
        System.out.println("  -> по реальному email запрос отрабатывает, "
                + "совпадение по паролю-заглушке: " + (r3 != null));
    }

    private static void header(String t) {
        System.out.println("\n========================================================");
        System.out.println("  " + t);
        System.out.println("========================================================");
    }

    private static void print(List<String> rows) {
        for (String r : rows) {
            System.out.println("  " + r);
        }
    }
}
