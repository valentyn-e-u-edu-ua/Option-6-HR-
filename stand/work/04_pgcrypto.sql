-- =====================================================================
-- Етап 4: Шифрування полів через pgcrypto
-- Варіант 06: HR-відділ компанії
-- =====================================================================
\set ON_ERROR_STOP on

-- Читаємо ключ із файлу у змінну psql (не потрапляє в історію)
\set enc_key `cat /work/enc_key.txt`

-- 1. Створюємо окрему схему для pgcrypto
CREATE SCHEMA ext;
REVOKE ALL ON SCHEMA ext FROM PUBLIC;
CREATE EXTENSION pgcrypto SCHEMA ext;
GRANT USAGE ON SCHEMA ext TO hr_specialist, accountant, hr_owner;

-- 2. Міграція: відкритий текст -> bytea
ALTER TABLE hr.employees
    ADD COLUMN id_card_no_enc bytea,
    ADD COLUMN iban_enc bytea;

UPDATE hr.employees SET
    id_card_no_enc = ext.pgp_sym_encrypt(id_card_no, :'enc_key', 'cipher-algo=aes256'),
    iban_enc = ext.pgp_sym_encrypt(iban, :'enc_key', 'cipher-algo=aes256');

ALTER TABLE hr.employees
    DROP COLUMN id_card_no,
    DROP COLUMN iban;

-- Фізично видаляємо старі відкриті версії рядків з диска
VACUUM FULL hr.employees;

-- 3. Представлення з розшифруванням (працює лише якщо передано ключ у сесії)
SET ROLE hr_owner;
CREATE VIEW hr.v_employees_decrypted WITH (security_invoker = true) AS
SELECT employee_id, last_name, first_name, department_id,
       ext.pgp_sym_decrypt(id_card_no_enc, current_setting('hr.enc_key', true)) AS id_card_no,
       ext.pgp_sym_decrypt(iban_enc, current_setting('hr.enc_key', true)) AS iban
FROM hr.employees;

GRANT SELECT ON hr.v_employees_decrypted TO hr_specialist, accountant;
RESET ROLE;