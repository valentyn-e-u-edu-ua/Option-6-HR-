#!/usr/bin/env bash
# Обгортка над docker-entrypoint.sh офіційного образу postgres.
set -e

# 1. TLS (етап 4). Сертифікати лежать у ./certs на хості й монтуються в /certs-src.
#    PostgreSQL вимагає, щоб ключ належав postgres і мав права 0600,
#    тому копіюємо їх усередину контейнера з потрібними правами.
if [ -f /certs-src/server.key ] && [ -f /certs-src/server.crt ]; then
    mkdir -p /etc/postgresql/certs
    install -o postgres -g postgres -m 0644 /certs-src/server.crt /etc/postgresql/certs/server.crt
    install -o postgres -g postgres -m 0600 /certs-src/server.key /etc/postgresql/certs/server.key
    if [ -f /certs-src/ca.crt ]; then
        install -o postgres -g postgres -m 0644 /certs-src/ca.crt /etc/postgresql/certs/ca.crt
    fi
fi

# 2. Каталог бекапів (етап 6): доступ лише системному користувачу postgres.
if [ -d /backups ]; then
    chown postgres:postgres /backups 2>/dev/null || true
    chmod 0700 /backups 2>/dev/null || true
fi

exec docker-entrypoint.sh "$@"
