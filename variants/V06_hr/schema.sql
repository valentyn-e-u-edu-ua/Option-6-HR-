-- =====================================================================
--  Практична робота «Захист БД PostgreSQL»
--  Варіант 06: HR-відділ компанії
--  Файл 1/2: схема (DDL)
--
--  Запуск (у вже створеній БД hr):
--      psql -U postgres -d hr -f schema.sql
--  Персональні / чутливі поля позначені в COMMENT ON COLUMN міткою [ПД] або [ЧУТЛИВЕ].
--  Ролі та права НЕ створюються тут — це завдання етапу 2.
-- =====================================================================

\set ON_ERROR_STOP on

CREATE SCHEMA IF NOT EXISTS hr;
COMMENT ON SCHEMA hr IS 'Варіант 06: кадровий облік, зарплати та відпустки компанії';

-- Підрозділи (відділи) компанії
CREATE TABLE hr.departments (
    department_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code             text NOT NULL UNIQUE,
    name             text NOT NULL UNIQUE,
    location         text NOT NULL,
    head_employee_id integer          -- FK додається після створення employees
);

-- Посади та «вилки» окладів
CREATE TABLE hr.positions (
    position_id  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title        text NOT NULL UNIQUE,
    grade        smallint NOT NULL CHECK (grade BETWEEN 1 AND 10),
    salary_min   numeric(10,2) NOT NULL CHECK (salary_min > 0),
    salary_max   numeric(10,2) NOT NULL,
    CHECK (salary_max >= salary_min)
);

-- Працівники — основна таблиця з персональними даними.
-- Поле db_login пов'язує працівника з обліковим записом PostgreSQL —
-- саме його використовуватиме RLS-політика (current_user) на етапі 3.
CREATE TABLE hr.employees (
    employee_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    personnel_no   text NOT NULL UNIQUE,
    last_name      text NOT NULL,
    first_name     text NOT NULL,
    middle_name    text,
    birth_date     date NOT NULL,
    phone          text NOT NULL,
    personal_email text,
    work_email     text NOT NULL UNIQUE,
    home_address   text NOT NULL,
    tax_id         text NOT NULL UNIQUE CHECK (tax_id ~ '^[0-9]{10}$'),
    id_card_no     text NOT NULL UNIQUE CHECK (id_card_no ~ '^[0-9]{9}$'),
    iban           text NOT NULL CHECK (iban ~ '^UA[0-9]{27}$'),
    department_id  integer NOT NULL REFERENCES hr.departments(department_id),
    position_id    integer NOT NULL REFERENCES hr.positions(position_id),
    hire_date      date NOT NULL,
    dismissal_date date,
    db_login       name UNIQUE,
    CHECK (dismissal_date IS NULL OR dismissal_date >= hire_date),
    CHECK (hire_date > birth_date + interval '16 years')
);
COMMENT ON TABLE  hr.employees                IS 'Працівники компанії';
COMMENT ON COLUMN hr.employees.last_name      IS '[ПД] Прізвище';
COMMENT ON COLUMN hr.employees.first_name     IS '[ПД] Ім''я';
COMMENT ON COLUMN hr.employees.middle_name    IS '[ПД] По батькові';
COMMENT ON COLUMN hr.employees.birth_date     IS '[ПД] Дата народження';
COMMENT ON COLUMN hr.employees.phone          IS '[ПД] Особистий телефон';
COMMENT ON COLUMN hr.employees.personal_email IS '[ПД] Особистий email';
COMMENT ON COLUMN hr.employees.work_email     IS '[ПД] Робочий email (корпоративний)';
COMMENT ON COLUMN hr.employees.home_address   IS '[ПД][ЧУТЛИВЕ] Адреса проживання';
COMMENT ON COLUMN hr.employees.tax_id         IS '[ПД][ЧУТЛИВЕ] РНОКПП (ІПН), 10 цифр; перші 5 цифр кодують дату народження';
COMMENT ON COLUMN hr.employees.id_card_no     IS '[ПД][ЧУТЛИВЕ] Номер ID-картки';
COMMENT ON COLUMN hr.employees.iban           IS '[ПД][ЧУТЛИВЕ] IBAN зарплатного рахунку';
COMMENT ON COLUMN hr.employees.department_id  IS 'Підрозділ працівника (для RLS)';
COMMENT ON COLUMN hr.employees.db_login       IS 'Логін PostgreSQL (для RLS); NULL — працівник не має доступу до БД';

ALTER TABLE hr.departments
    ADD CONSTRAINT departments_head_fk
    FOREIGN KEY (head_employee_id) REFERENCES hr.employees(employee_id);

-- Історія окладів (кожна зміна — окремий запис за наказом)
CREATE TABLE hr.salaries (
    salary_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id  integer NOT NULL REFERENCES hr.employees(employee_id),
    amount       numeric(10,2) NOT NULL CHECK (amount > 0),
    valid_from   date NOT NULL,
    valid_to     date,
    order_no     text NOT NULL,
    reason       text NOT NULL CHECK (reason IN ('hire', 'promotion', 'indexation', 'transfer', 'review')),
    CHECK (valid_to IS NULL OR valid_to > valid_from)
);
COMMENT ON COLUMN hr.salaries.employee_id IS '[ПД] Чий оклад';
COMMENT ON COLUMN hr.salaries.amount      IS '[ЧУТЛИВЕ] Посадовий оклад, грн/міс';

-- Нарахування та виплата зарплати (помісячно)
CREATE TABLE hr.payroll (
    payroll_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id   integer NOT NULL REFERENCES hr.employees(employee_id),
    period        date NOT NULL CHECK (extract(day FROM period) = 1),
    gross         numeric(10,2) NOT NULL CHECK (gross >= 0),
    bonus         numeric(10,2) NOT NULL DEFAULT 0 CHECK (bonus >= 0),
    pdfo          numeric(10,2) NOT NULL CHECK (pdfo >= 0),
    military_levy numeric(10,2) NOT NULL CHECK (military_levy >= 0),
    net           numeric(10,2) NOT NULL,
    paid_at       date,
    UNIQUE (employee_id, period),
    CHECK (net = gross + bonus - pdfo - military_levy)
);
COMMENT ON COLUMN hr.payroll.employee_id   IS '[ПД] Кому нараховано';
COMMENT ON COLUMN hr.payroll.gross         IS '[ЧУТЛИВЕ] Нараховано за окладом';
COMMENT ON COLUMN hr.payroll.bonus         IS '[ЧУТЛИВЕ] Премія';
COMMENT ON COLUMN hr.payroll.pdfo          IS '[ЧУТЛИВЕ] ПДФО 18 %';
COMMENT ON COLUMN hr.payroll.military_levy IS '[ЧУТЛИВЕ] Військовий збір 5 %';
COMMENT ON COLUMN hr.payroll.net           IS '[ЧУТЛИВЕ] До виплати';

-- Відпустки та лікарняні
CREATE TABLE hr.leave_requests (
    leave_id      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id   integer NOT NULL REFERENCES hr.employees(employee_id),
    leave_type    text NOT NULL CHECK (leave_type IN ('annual', 'sick', 'unpaid', 'study', 'maternity')),
    start_date    date NOT NULL,
    end_date      date NOT NULL,
    status        text NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
    approved_by   integer REFERENCES hr.employees(employee_id),
    sick_note_no  text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    CHECK (end_date >= start_date),
    CHECK (leave_type = 'sick' OR sick_note_no IS NULL)
);
COMMENT ON COLUMN hr.leave_requests.employee_id  IS '[ПД] Хто у відпустці / на лікарняному';
COMMENT ON COLUMN hr.leave_requests.leave_type   IS '[ПД] Тип відсутності (лікарняний, декрет — фактично дані про здоров''я)';
COMMENT ON COLUMN hr.leave_requests.sick_note_no IS '[ПД][ЧУТЛИВЕ] Номер електронного листка непрацездатності';

-- Оцінювання ефективності (заповнює керівник підрозділу)
CREATE TABLE hr.performance_reviews (
    review_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id  integer NOT NULL REFERENCES hr.employees(employee_id),
    reviewer_id  integer NOT NULL REFERENCES hr.employees(employee_id),
    period       text NOT NULL CHECK (period ~ '^[0-9]{4}-H[12]$'),
    score        smallint NOT NULL CHECK (score BETWEEN 1 AND 5),
    comment      text,
    created_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (employee_id, period),
    CHECK (reviewer_id <> employee_id)
);
COMMENT ON COLUMN hr.performance_reviews.score   IS '[ПД] Оцінка працівника';
COMMENT ON COLUMN hr.performance_reviews.comment IS '[ПД] Відгук керівника';

-- Дисциплінарні записи та заохочення (конфіденційні матеріали HR)
CREATE TABLE hr.disciplinary_notes (
    note_id      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id  integer NOT NULL REFERENCES hr.employees(employee_id),
    author_id    integer NOT NULL REFERENCES hr.employees(employee_id),
    note_type    text NOT NULL CHECK (note_type IN ('warning', 'reprimand', 'commendation', 'investigation')),
    note_text    text NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now()
);
COMMENT ON COLUMN hr.disciplinary_notes.employee_id IS '[ПД] Кого стосується запис';
COMMENT ON COLUMN hr.disciplinary_notes.note_type   IS '[ЧУТЛИВЕ] Вид запису';
COMMENT ON COLUMN hr.disciplinary_notes.note_text   IS '[ПД][ЧУТЛИВЕ] Зміст (догани, службові розслідування)';

CREATE INDEX ON hr.employees (department_id);
CREATE INDEX ON hr.employees (position_id);
CREATE INDEX ON hr.salaries (employee_id, valid_from);
CREATE INDEX ON hr.payroll (period);
CREATE INDEX ON hr.leave_requests (employee_id);
CREATE INDEX ON hr.performance_reviews (reviewer_id);
CREATE INDEX ON hr.disciplinary_notes (employee_id);
