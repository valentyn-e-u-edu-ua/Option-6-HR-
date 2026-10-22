# Ваші скрипти

Цей каталог доступний у контейнері як `/work`. Складайте сюди скрипти, з яких стенд розгортається з нуля, з номерами за етапами:

```
01_hardening_checks.sql
02_roles.sql
03_rls_masking.sql
04_pgcrypto.sql
05_audit.sql
06_backup.sh
06_restore.sh
```

Запуск: `docker compose exec -u postgres db psql -d <ваша_БД> -f /work/02_roles.sql`

Ключ шифрування етапу 4 (`enc_key.txt`) і паролі сюди теж можна класти, але вони виключені з git через `.gitignore`.
