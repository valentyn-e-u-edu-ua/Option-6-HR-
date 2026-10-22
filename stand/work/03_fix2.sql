\set ON_ERROR_STOP on
SET ROLE hr_owner;

-- Видаляємо стару функцію та політики
DROP POLICY emp_dept_head ON hr.employees;
DROP POLICY leave_dept_head ON hr.leave_requests;
DROP POLICY perf_dept_head ON hr.performance_reviews;
DROP FUNCTION hr.current_department_id();

-- Створюємо нову функцію, яка приймає логін як параметр
CREATE FUNCTION hr.current_department_id(p_login name) RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, hr
AS $$ 
    SELECT department_id FROM hr.employees WHERE db_login = p_login; 
$$;

GRANT EXECUTE ON FUNCTION hr.current_department_id(name) TO dept_head;

-- Оновлюємо політики, передаючи current_user як аргумент
CREATE POLICY emp_dept_head ON hr.employees 
    FOR SELECT TO dept_head 
    USING (department_id = hr.current_department_id(current_user));

CREATE POLICY leave_dept_head ON hr.leave_requests 
    FOR ALL TO dept_head
    USING (employee_id IN (SELECT employee_id FROM hr.employees WHERE department_id = hr.current_department_id(current_user)))
    WITH CHECK (employee_id IN (SELECT employee_id FROM hr.employees WHERE department_id = hr.current_department_id(current_user)));

CREATE POLICY perf_dept_head ON hr.performance_reviews 
    FOR ALL TO dept_head
    USING (employee_id IN (SELECT employee_id FROM hr.employees WHERE department_id = hr.current_department_id(current_user)))
    WITH CHECK (employee_id IN (SELECT employee_id FROM hr.employees WHERE department_id = hr.current_department_id(current_user)));

RESET ROLE;