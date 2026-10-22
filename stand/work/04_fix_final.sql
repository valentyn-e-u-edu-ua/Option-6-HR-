\set ON_ERROR_STOP on
SET ROLE hr_owner;

-- 1. Видаляємо представлення, яке блокує видалення колонки
DROP VIEW IF EXISTS hr.v_employees_accountant CASCADE;

-- 2. Тепер спокійно видаляємо старі відкриті колонки (дані вже зашифровані в iban_enc)
ALTER TABLE hr.employees DROP COLUMN IF EXISTS id_card_no, DROP COLUMN IF EXISTS iban;

-- 3. Відновлюємо представлення для бухгалтера (вже без відкритого IBAN)
CREATE VIEW hr.v_employees_accountant WITH (security_barrier = true) AS
SELECT employee_id, last_name, first_name, middle_name, department_id,
       hr.mask_tax_id(tax_id) AS tax_id, hire_date, dismissal_date
FROM hr.employees;

GRANT SELECT ON hr.v_employees_accountant TO accountant;

-- 4. Створюємо представлення для розшифрування (яке не встигло створитися)
CREATE VIEW hr.v_employees_decrypted WITH (security_invoker = true) AS
SELECT employee_id, last_name, first_name, department_id,
       ext.pgp_sym_decrypt(id_card_no_enc, current_setting('hr.enc_key', true)) AS id_card_no,
       ext.pgp_sym_decrypt(iban_enc, current_setting('hr.enc_key', true)) AS iban
FROM hr.employees;

GRANT SELECT ON hr.v_employees_decrypted TO hr_specialist, accountant;

RESET ROLE;