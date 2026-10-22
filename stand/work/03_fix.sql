\set ON_ERROR_STOP on

-- 1. Даємо керівникам і порталу право читати ЛИШЕ нечутливі стовпці таблиці (без ІПН та адрес)
-- Тепер представлення з RLS працюватиме, але прямий запит до ПД буде заблоковано.
GRANT SELECT (employee_id, last_name, first_name, middle_name, work_email, department_id, position_id, hire_date, db_login) 
ON hr.employees TO dept_head, app_hrportal;

-- 2. Переробляємо представлення для бухгалтера
-- Оскільки бухгалтер взагалі не повинен мати доступу до ІПН, представлення має працювати від імені власника (без security_invoker)
SET ROLE hr_owner;
DROP VIEW hr.v_employees_accountant;

CREATE VIEW hr.v_employees_accountant WITH (security_barrier = true) AS
SELECT employee_id, last_name, first_name, middle_name, department_id,
       hr.mask_tax_id(tax_id) AS tax_id, iban, hire_date, dismissal_date
FROM hr.employees;

GRANT SELECT ON hr.v_employees_accountant TO accountant;
RESET ROLE;