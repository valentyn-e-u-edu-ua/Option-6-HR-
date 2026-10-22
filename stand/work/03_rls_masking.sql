-- =====================================================================
-- Етап 3: Row-Level Security і маскування
-- Варіант 06: HR-відділ компанії
-- =====================================================================
\set ON_ERROR_STOP on
SET ROLE hr_owner;

-- 1. Допоміжна функція: підрозділ поточного керівника (SECURITY DEFINER)
-- Захист від рекурсії (щоб політика не зациклилась сама на собі)
CREATE FUNCTION hr.current_department_id() RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, hr
AS $$ 
    SELECT department_id FROM hr.employees WHERE db_login = current_user; 
$$;

GRANT EXECUTE ON FUNCTION hr.current_department_id() TO dept_head;

-- 2. Вмикаємо RLS на потрібних таблицях
ALTER TABLE hr.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr.leave_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr.performance_reviews ENABLE ROW LEVEL SECURITY;

-- 3. Політики для HR та Бухгалтера (бачать усі рядки, які їм дозволено через GRANT)
CREATE POLICY emp_hr_all ON hr.employees FOR ALL TO hr_specialist USING (true) WITH CHECK (true);
CREATE POLICY leave_hr_all ON hr.leave_requests FOR ALL TO hr_specialist, accountant USING (true) WITH CHECK (true);
CREATE POLICY perf_hr_all ON hr.performance_reviews FOR ALL TO hr_specialist USING (true) WITH CHECK (true);

-- 4. Політики для Керівника підрозділу (dept_head) - лише свій підрозділ
CREATE POLICY emp_dept_head ON hr.employees 
    FOR SELECT TO dept_head 
    USING (department_id = hr.current_department_id());

CREATE POLICY leave_dept_head ON hr.leave_requests 
    FOR ALL TO dept_head
    USING (employee_id IN (SELECT employee_id FROM hr.employees WHERE department_id = hr.current_department_id()))
    WITH CHECK (employee_id IN (SELECT employee_id FROM hr.employees WHERE department_id = hr.current_department_id()));

CREATE POLICY perf_dept_head ON hr.performance_reviews 
    FOR ALL TO dept_head
    USING (employee_id IN (SELECT employee_id FROM hr.employees WHERE department_id = hr.current_department_id()))
    WITH CHECK (employee_id IN (SELECT employee_id FROM hr.employees WHERE department_id = hr.current_department_id()));

-- 5. Політика для корпоративного порталу (дозволяє бачити всіх)
CREATE POLICY emp_portal_all ON hr.employees FOR SELECT TO app_hrportal USING (true);

-- 6. Функції маскування
-- Бухгалтеру потрібен ІПН, але сховаємо частину цифр, щоб не світити дату народження
CREATE FUNCTION hr.mask_tax_id(tax text) RETURNS text
LANGUAGE sql IMMUTABLE STRICT
AS $$ SELECT left(tax, 2) || '******' || right(tax, 2) $$;

-- 7. Масковані представлення
-- Довідник для порталу та керівників (БЕЗ ІПН, IBAN, адрес)
CREATE VIEW hr.v_employees_directory WITH (security_invoker = true) AS
SELECT e.employee_id, e.last_name, e.first_name, e.middle_name, e.work_email,
       d.name AS department_name, p.title AS position_title, e.hire_date
FROM hr.employees e
JOIN hr.departments d USING (department_id)
JOIN hr.positions p USING (position_id);

GRANT SELECT ON hr.v_employees_directory TO app_hrportal, dept_head;

-- Довідник для бухгалтера (з маскованим ІПН)
CREATE VIEW hr.v_employees_accountant WITH (security_invoker = true) AS
SELECT employee_id, last_name, first_name, middle_name, department_id,
       hr.mask_tax_id(tax_id) AS tax_id, iban, hire_date, dismissal_date
FROM hr.employees;

GRANT EXECUTE ON FUNCTION hr.mask_tax_id(text) TO accountant;
GRANT SELECT ON hr.v_employees_accountant TO accountant;

RESET ROLE;