# Стенд практичної роботи «Захист БД PostgreSQL»

PostgreSQL 16 + `pgaudit` + `pgcrypto` у Docker. Працює однаково на Windows (Docker Desktop), macOS і Linux. Повний опис кожного етапу — у методичних вказівках; тут лише запуск.

## Що потрібно

- Docker Desktop (Windows/macOS) або Docker Engine + Compose plugin (Linux)
- ≈ 2 ГБ вільного місця; інтернет для першої збірки образів
- Окремо встановлювати PostgreSQL чи Python **не потрібно** — усе є в контейнерах

## Структура

```
stand/
├── docker-compose.yml     сервіси: db, restore, client, app
├── Dockerfile             образ postgres:16 + pgaudit + gnupg + openssl
├── stand-entrypoint.sh    копіює TLS-ключі з правильними правами
├── conf/                  postgresql.conf, pg_hba.conf  ← НАВМИСНО небезпечні, виправляєте на етапі 1
├── secrets/               паролі (у git не комітити!)
├── certs/                 сертифікати TLS (етап 4)
├── backups/               зашифровані бекапи (етап 6)
├── work/                  ВАШІ скрипти: 01_…sql, 02_…sql, …  (у контейнері — /work)
├── scripts/gen_certs.sh   генерація власного CA і сертифіката сервера
└── app/                   Python-застосунок для етапу 7
```

Каталог `../variants` монтується в контейнер як `/variants` (лише читання).

## Перший запуск

**1. Створіть секрети** (без переносу рядка в кінці!)

PowerShell:
```powershell
cd stand
$p = -join ((48..57)+(65..90)+(97..122) | Get-Random -Count 24 | % {[char]$_})
Set-Content -NoNewline -Encoding ascii secrets\pg_superuser_password.txt $p
$b = -join ((48..57)+(65..90)+(97..122) | Get-Random -Count 32 | % {[char]$_})
Set-Content -NoNewline -Encoding ascii secrets\backup_passphrase.txt $b
```

bash (Linux / macOS / Git Bash):
```bash
cd stand
openssl rand -base64 24 | tr -d '\n' > secrets/pg_superuser_password.txt
openssl rand -base64 32 | tr -d '\n' > secrets/backup_passphrase.txt
```

**2. Зберіть і запустіть**
```bash
docker compose up -d --build
docker compose ps                       # STATUS має бути "running"
docker compose logs db --tail 20        # "database system is ready to accept connections"
```

**3. Розгорніть свій варіант** (приклад для варіанта 01)
```bash
docker compose exec -u postgres db psql -c "CREATE DATABASE clinic"
docker compose exec -u postgres db psql -d clinic -f /variants/V01_clinic/schema.sql
docker compose exec -u postgres db psql -d clinic -f /variants/V01_clinic/seed.sql
```

**4. Інтерактивна консоль**
```bash
docker compose exec -u postgres db psql -d clinic
```

> Чому `-u postgres`? Команда `docker compose exec` за замовчуванням працює від root. Після hardening (етап 1) суперкористувач входить лише за методом `peer`, тобто ім'я ОС-користувача має збігатися з ім'ям ролі.

## Корисні команди

| Дія | Команда |
|---|---|
| Перечитати конфіг без перезапуску | `docker compose exec -u postgres db psql -c "SELECT pg_reload_conf()"` |
| Перезапустити сервер | `docker compose restart db` |
| Журнал сервера | `docker compose logs db --since 10m` |
| Клієнт psql «ззовні» (інший контейнер) | `docker compose run --rm client psql "host=db dbname=clinic user=..."` |
| Зупинити, дані зберегти | `docker compose down` |
| **Знищити все й почати з нуля** | `docker compose down -v` |

## Якщо щось не так

- **Порт 5432 зайнятий** (локальний PostgreSQL): змініть у `docker-compose.yml` на `"127.0.0.1:15432:5432"`.
- **Сервер не стартує після зміни конфіга**: `docker compose logs db --tail 30` — PostgreSQL пише, в якому рядку помилка.
- **`FATAL: no pg_hba.conf entry`**: так і має бути, якщо правило не дозволяє. Подивіться `SELECT * FROM pg_hba_file_rules;` і журнал (`log_connections`).
- **Заблокували самі себе**: виправте `conf/pg_hba.conf` на хості й виконайте `docker compose restart db`.

**Порти публікуються лише на `127.0.0.1`. Не відкривайте стенд у мережу.**
