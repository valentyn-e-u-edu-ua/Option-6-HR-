# Застосунок для етапу 7

Покладіть сюди свій `sqli_demo.py` (зразок — у методичних вказівках, етап 7).

```bash
docker compose build app
docker compose run --rm -e PGPASSWORD app python sqli_demo.py vuln "рядок пошуку"
```

Контейнер `app` має фіксовану адресу `172.28.0.30` — на неї можна обмежити правило `pg_hba.conf` для сервісного облікового запису.
