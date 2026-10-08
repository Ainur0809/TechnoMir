# TechnoMir

Проект интернет-магазина бытовой техники.

## Структура проекта

- `initdb/` - инициализация БД
  - `01-schema.sql` - схема БД (источник правды)
  - `02-data.sql` - тестовые данные
- `docker-compose.yml` - конфигурация Docker
- `schema.dbml` - диаграмма БД (DBML формат)
- `queries.sql` - SQL запросы
- `injection.md` - документация по защите от SQL инъекций
- `DAY1_NOTES.md` - заметки первого дня разработки

## Запуск проекта

```bash
docker-compose up
```
