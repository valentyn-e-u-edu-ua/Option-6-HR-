# Образ стенда практичної роботи: офіційний PostgreSQL 16 + pgaudit + інструменти
# для шифрування бекапів (gnupg) і генерації сертифікатів (openssl).
FROM postgres:16-bookworm

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        postgresql-16-pgaudit \
        gnupg \
        openssl \
 && rm -rf /var/lib/apt/lists/*

# Обгортка над стандартним entrypoint: копіює TLS-ключі з правильними правами
# (на Windows примонтовані файли мають права 0777, і PostgreSQL відмовиться їх читати).
COPY stand-entrypoint.sh /usr/local/bin/stand-entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/stand-entrypoint.sh \
 && chmod 0755 /usr/local/bin/stand-entrypoint.sh

ENTRYPOINT ["stand-entrypoint.sh"]
CMD ["postgres", "-c", "config_file=/etc/postgresql/conf/postgresql.conf"]
