#!/bin/bash
# Демо-сайт ТехноМир: компиляция и запуск.
# Нужны: Java 17+ и запущенная база (docker compose up -d в корне проекта).
# Открыть после запуска: http://localhost:8088
set -e
cd "$(dirname "$0")"

VERSION=42.7.4
DRIVER=""
# 1) драйвер PostgreSQL уже скачан Maven/IntelliJ — берём из ~/.m2
for jar in "$HOME"/.m2/repository/org/postgresql/postgresql/*/postgresql-*.jar; do
  [ -f "$jar" ] && DRIVER="$jar"
done
# 2) иначе — скачиваем один раз в web/lib
if [ -z "$DRIVER" ]; then
  DRIVER="lib/postgresql-$VERSION.jar"
  if [ ! -f "$DRIVER" ]; then
    echo "Скачиваю драйвер PostgreSQL JDBC $VERSION..."
    mkdir -p lib
    curl -fsSL -o "$DRIVER" \
      "https://repo1.maven.org/maven2/org/postgresql/postgresql/$VERSION/postgresql-$VERSION.jar" ||
    curl -fsSL -o "$DRIVER" \
      "https://github.com/pgjdbc/pgjdbc/releases/download/REL$VERSION/postgresql-$VERSION.jar"
  fi
fi

mkdir -p out
javac -encoding UTF-8 -cp "$DRIVER" -d out src/*.java
exec java -Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8 -cp "out:$DRIVER" App
