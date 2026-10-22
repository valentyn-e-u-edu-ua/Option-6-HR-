-- =====================================================================
-- Етап 2: Матриця доступу, ролі, мінімальні привілеї
-- Варіант 06: HR-відділ компанії
-- Виконувати як postgres у БД hr:
-- docker compose exec -u postgres db psql -d hr -f /work/02_roles.sql
-- =====================================================================
\set ON_ERROR_STOP on

-- 1. Прибираємо права за замовчуванням у PUBLIC
REVOKE ALL ON DATABASE hr FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA hr FROM PUBLIC;

-- 2. Створюємо власника об'єктів (без права входу), щоб власником не був postgres
CREATE ROLE hr_owner NOLOGIN;
ALTER SCHEMA hr OWNER TO hr_owner;

DO $$
DECLARE r record;
BEGIN
    FOR r IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname = 'hr' AND c.relkind IN ('r','p')
    LOOP
        EXECUTE format('ALTER TABLE hr.%I OWNER TO hr_owner', r.relname);
    END LOOP;
END $$;

-- 3. Групові ролі (посади - NOLOGIN)
CREATE ROLE hr_specialist NOLOGIN;
CREATE ROLE accountant    NOLOGIN;
CREATE ROLE dept_head     NOLOGIN;
CREATE ROLE app_hrportal  NOLOGIN;

GRANT CONNECT ON DATABASE hr TO hr_specialist, accountant, dept_head, app_hrportal;
GRANT USAGE   ON SCHEMA hr   TO hr_specialist, accountant, dept_head, app_hrportal;

-- 4. Видача привілеїв згідно з матрицею доступу
-- HR-відділ: повний кадровий облік, але без доступу до виплат (payroll)
GRANT SELECT, INSERT, UPDATE ON hr.departments, hr.positions, hr.employees, hr.disciplinary_notes TO hr_specialist;
GRANT SELECT, INSERT ON hr.salaries TO hr_specialist;
GRANT SELECT, INSERT, UPDATE ON hr.leave_requests TO hr_specialist;
GRANT SELECT ON hr.performance_reviews TO hr_specialist;

-- Бухгалтерія: доступ до виплат, читання кадрів, АЛЕ без доступу до медичних даних
GRANT SELECT ON hr.departments, hr.positions, hr.salaries TO accountant;
GRANT SELECT, INSERT, UPDATE ON hr.payroll TO accountant;
-- Видаємо доступ до відпусток ТОЧКОВО по стовпцях (без sick_note_no)
GRANT SELECT (leave_id, employee_id, leave_type, start_date, end_date, status, approved_by, created_at) ON hr.leave_requests TO accountant;

-- Керівник підрозділу: базові права (обмеження рядків налаштуємо через RLS на Етапі 3)
GRANT SELECT ON hr.departments, hr.positions TO dept_head;
GRANT SELECT, INSERT, UPDATE ON hr.performance_reviews TO dept_head;
GRANT SELECT ON hr.leave_requests TO dept_head;
GRANT UPDATE (status, approved_by) ON hr.leave_requests TO dept_head;

-- Портал самообслуговування (сервісний акаунт)
GRANT SELECT ON hr.departments, hr.positions TO app_hrportal;
GRANT INSERT ON hr.leave_requests TO app_hrportal;

-- Дозволяємо використання послідовностей для додавання нових рядків
GRANT USAGE ON ALL SEQUENCES IN SCHEMA hr TO hr_specialist, accountant, dept_head, app_hrportal;

-- 5. Права на майбутні об'єкти та функції
ALTER DEFAULT PRIVILEGES FOR ROLE hr_owner IN SCHEMA hr
    GRANT SELECT ON TABLES TO hr_specialist;
ALTER DEFAULT PRIVILEGES FOR ROLE hr_owner
    REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- 6. Логіни співробітників (LOGIN) із терміном дії та лімітом підключень
CREATE ROLE u_hr1         LOGIN IN ROLE hr_specialist VALID UNTIL '2027-01-01' CONNECTION LIMIT 3;
CREATE ROLE u_hr2         LOGIN IN ROLE hr_specialist VALID UNTIL '2027-01-01' CONNECTION LIMIT 3;
CREATE ROLE u_accountant1 LOGIN IN ROLE accountant    VALID UNTIL '2027-01-01' CONNECTION LIMIT 3;
CREATE ROLE u_accountant2 LOGIN IN ROLE accountant    VALID UNTIL '2027-01-01' CONNECTION LIMIT 3;
CREATE ROLE u_dept_head1  LOGIN IN ROLE dept_head     VALID UNTIL '2027-01-01' CONNECTION LIMIT 3;
CREATE ROLE u_dept_head2  LOGIN IN ROLE dept_head     VALID UNTIL '2027-01-01' CONNECTION LIMIT 3;
CREATE ROLE u_dept_head3  LOGIN IN ROLE dept_head     VALID UNTIL '2027-01-01' CONNECTION LIMIT 3;
CREATE ROLE u_dept_head4  LOGIN IN ROLE dept_head     VALID UNTIL '2027-01-01' CONNECTION LIMIT 3;

-- Сервісний обліковий запис порталу (обмеження часу виконання запиту - statement_timeout)
CREATE ROLE svc_hrportal LOGIN IN ROLE app_hrportal CONNECTION LIMIT 20;
ALTER ROLE svc_hrportal SET statement_timeout = '5s';
ALTER ROLE svc_hrportal SET search_path = hr;