#!/bin/bash
# Компиляция и запуск учебного стенда части 8.
# Требуется запущенная база shop (docker compose up -d) и драйвер
# PostgreSQL JDBC в локальном репозитории Maven (~/.m2).
set -e
cd "$(dirname "$0")"

DRIVER="$HOME/.m2/repository/org/postgresql/postgresql/42.7.2/postgresql-42.7.2.jar"
if [ ! -f "$DRIVER" ]; then
  echo "Не найден драйвер: $DRIVER"
  echo "Скачайте postgresql-42.7.2.jar или поправьте путь в run.sh."
  exit 1
fi

mkdir -p out
javac -d out src/*.java
java -cp "out:$DRIVER" Main
