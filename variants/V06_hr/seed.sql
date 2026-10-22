-- =====================================================================
--  Варіант 06: HR-відділ компанії
--  Файл 2/2: тестові дані
--  УСІ ДАНІ СИНТЕТИЧНІ. Збіги з реальними людьми випадкові.
--  Генерація детермінована (setseed) — у всіх студентів однакові дані.
--
--      psql -U postgres -d hr -f seed.sql
-- =====================================================================

\set ON_ERROR_STOP on
SET search_path = hr;
SELECT setseed(0.06);

-- Довідкові масиви для генерації
CREATE TEMP TABLE _n AS SELECT
    ARRAY['Шевченко','Коваленко','Бондаренко','Ткаченко','Кравченко','Олійник','Шевчук',
          'Поліщук','Мельник','Бойко','Мороз','Лисенко','Руденко','Савченко','Петренко',
          'Марченко','Гончаренко','Павленко','Левченко','Кузьменко','Ковальчук','Литвиненко',
          'Захарченко','Романенко','Карпенко'] AS last_names,
    ARRAY['Олександр','Андрій','Дмитро','Максим','Іван','Сергій','Богдан','Тарас',
          'Олег','Юрій','Петро','Назар','Віктор','Микола','Василь','Роман'] AS male_names,
    ARRAY['Олена','Наталія','Ірина','Оксана','Марія','Анна','Тетяна','Юлія',
          'Катерина','Софія','Вікторія','Ганна','Дарина','Людмила','Світлана','Галина'] AS female_names,
    ARRAY['Олександрович','Андрійович','Дмитрович','Максимович','Іванович','Сергійович',
          'Богданович','Тарасович','Олегович','Юрійович','Петрович','Назарович',
          'Вікторович','Миколайович','Васильович','Романович'] AS patr_m,
    ARRAY['Олександрівна','Андріївна','Дмитрівна','Максимівна','Іванівна','Сергіївна',
          'Богданівна','Тарасівна','Олегівна','Юріївна','Петрівна','Назарівна',
          'Вікторівна','Миколаївна','Василівна','Романівна'] AS patr_f,
    ARRAY['Хрещатик','Володимирська','Січових Стрільців','Велика Васильківська',
          'Антоновича','Саксаганського','Лесі Українки','Б. Хмельницького',
          'Ярославів Вал','Іллєнка','Межигірська','Харківське шосе'] AS streets,
    ARRAY['50','63','66','67','68','73','93','95','96','97','98','99'] AS ops,
    ARRAY['305299','322001','300465','380805','320649','351005'] AS bank_codes;

-- Підрозділи (керівників призначимо після створення працівників)
INSERT INTO departments (code, name, location) VALUES
    ('HR',    'Відділ кадрів',      'м. Київ, вул. Антоновича, 48, оф. 301'),
    ('FIN',   'Бухгалтерія',        'м. Київ, вул. Антоновича, 48, оф. 305'),
    ('DEV',   'Відділ розробки',    'м. Київ, вул. Антоновича, 48, поверх 4'),
    ('SALES', 'Відділ продажів',    'м. Київ, вул. Антоновича, 48, поверх 2'),
    ('SUP',   'Служба підтримки',   'м. Київ, вул. Межигірська, 25'),
    ('LOG',   'Відділ логістики',   'м. Київ, Харківське шосе, 175, склад №2');

-- Посади (position_id 1..16 у порядку вставки)
INSERT INTO positions (title, grade, salary_min, salary_max) VALUES
    ('HR-менеджер',                  5, 25000,  45000),   -- 1
    ('Рекрутер',                     4, 20000,  35000),   -- 2
    ('Головний бухгалтер',           8, 55000,  80000),   -- 3
    ('Бухгалтер',                    5, 25000,  42000),   -- 4
    ('Керівник відділу',             8, 60000, 110000),   -- 5
    ('Старший розробник',            7, 70000, 120000),   -- 6
    ('Розробник',                    6, 45000,  75000),   -- 7
    ('Молодший розробник',           4, 25000,  40000),   -- 8
    ('Тестувальник',                 5, 30000,  55000),   -- 9
    ('Менеджер з продажу',           4, 20000,  40000),   -- 10
    ('Старший менеджер з продажу',   6, 35000,  60000),   -- 11
    ('Оператор підтримки',           3, 16000,  25000),   -- 12
    ('Старший оператор підтримки',   4, 22000,  32000),   -- 13
    ('Логіст',                       4, 22000,  38000),   -- 14
    ('Комірник',                     2, 15000,  22000),   -- 15
    ('Водій-експедитор',             3, 18000,  28000);   -- 16

-- 150 працівників. Розподіл по відділах: HR 8, FIN 10, DEV 50, SALES 35, SUP 30, LOG 17.
-- Перший працівник кожного відділу — його керівник.
WITH base AS MATERIALIZED (
    SELECT g,
           CASE WHEN g <=   8 THEN 1 WHEN g <=  18 THEN 2 WHEN g <=  68 THEN 3
                WHEN g <= 103 THEN 4 WHEN g <= 133 THEN 5 ELSE 6 END   AS dep,
           g IN (1, 9, 19, 69, 104, 134)                               AS is_head,
           random() < 0.5                                              AS male,
           1 + floor(random() * 25)::int                               AS ln,
           1 + floor(random() * 16)::int                               AS fn,
           1 + floor(random() * 16)::int                               AS pn,
           date '1965-01-01' + floor(random() * CASE WHEN g IN (1, 9, 19, 69, 104, 134)
                                                     THEN 7000 ELSE 14000 END)::int AS birth,
           random() AS r_hire, random() AS r_pos, random() AS r_dis
    FROM generate_series(1, 150) AS g
), b AS MATERIALIZED (
    SELECT *,
           greatest(date '2012-01-01'
                        + floor(r_hire * (current_date - 90 - date '2012-01-01'))::int,
                    (birth + interval '19 years')::date) AS hire
    FROM base
)
INSERT INTO employees (personnel_no, last_name, first_name, middle_name, birth_date,
                       phone, personal_email, work_email, home_address,
                       tax_id, id_card_no, iban, department_id, position_id,
                       hire_date, dismissal_date)
SELECT
    'ТН-' || lpad(b.g::text, 5, '0'),
    n.last_names[b.ln],
    CASE WHEN b.male THEN n.male_names[b.fn] ELSE n.female_names[b.fn] END,
    CASE WHEN b.male THEN n.patr_m[b.pn]     ELSE n.patr_f[b.pn]       END,
    b.birth,
    '+380' || n.ops[1 + floor(random() * array_length(n.ops, 1))::int]
           || lpad(floor(random() * 10000000)::text, 7, '0'),
    CASE WHEN random() < 0.8 THEN 'person' || b.g || '@example.com' END,
    'employee' || b.g || '@example.com',
    'м. Київ, вул. ' || n.streets[1 + floor(random() * array_length(n.streets, 1))::int]
           || ', ' || (1 + floor(random() * 120))::int
           || ', кв. ' || (1 + floor(random() * 200))::int,
    -- РНОКПП: 5 цифр = кількість днів від 31.12.1899 до дати народження + 5 випадкових
    lpad((b.birth - date '1899-12-31')::text, 5, '0')
           || lpad(floor(random() * 100000)::text, 5, '0'),
    lpad(floor(random() * 1000000000)::text, 9, '0'),
    'UA' || lpad(floor(random() * 100)::text, 2, '0')
         || n.bank_codes[1 + floor(random() * array_length(n.bank_codes, 1))::int]
         || '00000' || lpad(floor(random() * 1e14)::bigint::text, 14, '0'),
    b.dep,
    CASE WHEN b.is_head THEN CASE WHEN b.dep = 2 THEN 3 ELSE 5 END
         ELSE CASE b.dep
              WHEN 1 THEN (ARRAY[1, 1, 2])[1 + floor(b.r_pos * 3)::int]
              WHEN 2 THEN 4
              WHEN 3 THEN (ARRAY[6, 7, 7, 7, 8, 8, 9, 9])[1 + floor(b.r_pos * 8)::int]
              WHEN 4 THEN (ARRAY[10, 10, 10, 11])[1 + floor(b.r_pos * 4)::int]
              WHEN 5 THEN (ARRAY[12, 12, 12, 13])[1 + floor(b.r_pos * 4)::int]
              ELSE        (ARRAY[14, 14, 15, 16, 16])[1 + floor(b.r_pos * 5)::int]
              END
    END,
    b.hire,
    CASE WHEN NOT b.is_head AND b.g % 15 = 7
         THEN b.hire + 30 + floor(b.r_dis * (current_date - b.hire - 31))::int END
FROM b, _n AS n
ORDER BY b.g;

-- Керівники підрозділів
UPDATE departments d SET head_employee_id = e.employee_id
FROM employees e
WHERE e.personnel_no = 'ТН-' || lpad((ARRAY[1, 9, 19, 69, 104, 134])[d.department_id]::text, 5, '0');

-- Логіни PostgreSQL. db_login збігатиметься з логінами, які ви створите на етапі 2.
--   u_hr1, u_hr2               — працівники відділу кадрів (u_hr1 — його керівник)
--   u_accountant1, u_accountant2 — бухгалтерія (u_accountant1 — головний бухгалтер)
--   u_dept_head1..4            — керівники DEV, SALES, SUP, LOG
UPDATE employees e SET db_login = v.login
FROM (VALUES ('ТН-00001', 'u_hr1'),         ('ТН-00002', 'u_hr2'),
             ('ТН-00009', 'u_accountant1'), ('ТН-00010', 'u_accountant2'),
             ('ТН-00019', 'u_dept_head1'),  ('ТН-00069', 'u_dept_head2'),
             ('ТН-00104', 'u_dept_head3'),  ('ТН-00134', 'u_dept_head4')) AS v(pno, login)
WHERE e.personnel_no = v.pno;

-- Оклад при прийнятті на роботу
INSERT INTO salaries (employee_id, amount, valid_from, order_no, reason)
SELECT e.employee_id,
       round((p.salary_min + random() * (p.salary_max - p.salary_min) * 0.7) / 500) * 500,
       e.hire_date,
       'НК-' || to_char(e.hire_date, 'YYYY') || '/П-' || lpad(e.employee_id::text, 3, '0'),
       'hire'
FROM employees e JOIN positions p USING (position_id)
ORDER BY e.employee_id;

-- Підвищення окладу (індексація / підвищення / перегляд) для більшості «старих» працівників
WITH c AS MATERIALIZED (
    SELECT s.employee_id, s.amount,
           greatest(e.hire_date + 365, date '2024-01-01') + floor(random() * 400)::int AS vf,
           random() AS r
    FROM salaries s JOIN employees e USING (employee_id)
    WHERE e.dismissal_date IS NULL AND e.hire_date < current_date - 450
)
INSERT INTO salaries (employee_id, amount, valid_from, order_no, reason)
SELECT employee_id,
       round(amount * (1.08 + r * 0.2) / 500) * 500,
       vf,
       'НК-' || to_char(vf, 'YYYY') || '/З-' || lpad(employee_id::text, 3, '0'),
       (ARRAY['indexation', 'promotion', 'review'])[1 + floor(random() * 3)::int]
FROM c
WHERE vf < current_date - 30 AND r < 0.85
ORDER BY employee_id;

UPDATE salaries s SET valid_to = nx.valid_from - 1
FROM salaries nx
WHERE nx.employee_id = s.employee_id AND nx.valid_from > s.valid_from;

UPDATE salaries s SET valid_to = e.dismissal_date
FROM employees e
WHERE e.employee_id = s.employee_id AND e.dismissal_date IS NOT NULL AND s.valid_to IS NULL;

-- Зарплатна відомість за три останні завершені місяці
WITH x AS MATERIALIZED (
    SELECT e.employee_id, m.period, s.amount AS gross,
           CASE WHEN random() < 0.3
                THEN round(s.amount * (0.05 + random() * 0.25)::numeric / 100) * 100
                ELSE 0 END::numeric(10,2) AS bonus
    FROM employees e
    CROSS JOIN (SELECT (date_trunc('month', current_date) - make_interval(months => k))::date AS period
                FROM generate_series(1, 3) AS k) AS m
    JOIN LATERAL (
        SELECT amount FROM salaries s
        WHERE s.employee_id = e.employee_id AND s.valid_from <= m.period + 27
        ORDER BY s.valid_from DESC LIMIT 1
    ) s ON true
    WHERE e.hire_date < m.period
      AND (e.dismissal_date IS NULL OR e.dismissal_date >= m.period + 27)
), t AS MATERIALIZED (
    SELECT *, round((gross + bonus) * 0.18, 2) AS pdfo,
              round((gross + bonus) * 0.05, 2) AS levy
    FROM x
)
INSERT INTO payroll (employee_id, period, gross, bonus, pdfo, military_levy, net, paid_at)
SELECT employee_id, period, gross, bonus, pdfo, levy,
       gross + bonus - pdfo - levy,
       CASE WHEN period + interval '1 month 5 days' < current_date
            THEN (period + interval '1 month 5 days')::date END
FROM t
ORDER BY period, employee_id;

-- Відпустки та лікарняні (≈ 240)
WITH x AS MATERIALIZED (
    SELECT e.employee_id, e.hire_date, d.head_employee_id,
           (ARRAY['annual','annual','annual','annual','annual','annual',
                  'sick','sick','sick','unpaid','study'])[1 + floor(random() * 11)::int] AS lt,
           current_date - 420 + floor(random() * 480)::int AS sd,
           random() AS r, random() AS r2, random() AS r3
    FROM (SELECT 1 + floor(random() * 150)::int AS eid FROM generate_series(1, 260)) AS g
    JOIN employees e ON e.employee_id = g.eid
    JOIN departments d USING (department_id)
    WHERE e.dismissal_date IS NULL
), y AS MATERIALIZED (
    SELECT *,
           greatest(sd, hire_date + 30) AS sd2,
           CASE WHEN lt = 'sick' THEN 'approved'
                WHEN greatest(sd, hire_date + 30) > current_date
                     THEN CASE WHEN r2 < 0.5 THEN 'pending' ELSE 'approved' END
                WHEN r2 < 0.88 THEN 'approved'
                WHEN r2 < 0.95 THEN 'rejected'
                ELSE 'cancelled' END AS st
    FROM x
)
INSERT INTO leave_requests (employee_id, leave_type, start_date, end_date, status,
                            approved_by, sick_note_no, created_at)
SELECT employee_id, lt, sd2,
       sd2 + CASE lt WHEN 'annual' THEN 6 + floor(r * 18)::int
                     WHEN 'sick'   THEN 2 + floor(r * 12)::int
                     WHEN 'unpaid' THEN floor(r * 5)::int
                     ELSE 4 + floor(r * 15)::int END,
       st,
       CASE WHEN st IN ('approved', 'rejected') THEN
            CASE WHEN head_employee_id <> employee_id THEN head_employee_id
                 WHEN employee_id = 1 THEN 2 ELSE 1 END END,
       CASE WHEN lt = 'sick' THEN
            lpad(floor(r3 * 10000)::text, 4, '0') || '-' ||
            lpad(floor(random() * 10000)::text, 4, '0') || '-' ||
            lpad(floor(random() * 10000)::text, 4, '0') || '-' ||
            lpad(floor(random() * 10000)::text, 4, '0') END,
       least(now(),
             CASE WHEN lt = 'sick' THEN sd2 + interval '1 day' + r3 * interval '10 hours'
                  ELSE sd2 - interval '7 days' - r3 * interval '20 days' END)
FROM y
ORDER BY sd2;

-- Декретні відпустки (3 працівниці)
INSERT INTO leave_requests (employee_id, leave_type, start_date, end_date, status, approved_by, created_at)
SELECT e.employee_id, 'maternity', current_date - 60, current_date + 65, 'approved',
       1, current_date - 75
FROM employees e
WHERE e.middle_name LIKE '%на' AND e.dismissal_date IS NULL AND e.db_login IS NULL
ORDER BY e.employee_id DESC
LIMIT 3;

-- Оцінювання ефективності: тільки підрозділи DEV, SALES, SUP, LOG, оцінює керівник
WITH x AS MATERIALIZED (
    SELECT e.employee_id, d.head_employee_id, p.period, p.pend,
           (ARRAY[2, 3, 3, 4, 4, 4, 4, 5, 5, 1])[1 + floor(random() * 10)::int] AS score,
           random() AS r
    FROM employees e
    JOIN departments d USING (department_id)
    CROSS JOIN (VALUES ('2025-H1', date '2025-06-30'),
                       ('2025-H2', date '2025-12-31'),
                       ('2026-H1', date '2026-06-30')) AS p(period, pend)
    WHERE d.code IN ('DEV', 'SALES', 'SUP', 'LOG')
      AND e.employee_id <> d.head_employee_id
      AND e.hire_date < p.pend - 90
      AND (e.dismissal_date IS NULL OR e.dismissal_date > p.pend)
      AND p.pend < current_date
)
INSERT INTO performance_reviews (employee_id, reviewer_id, period, score, comment, created_at)
SELECT employee_id, head_employee_id, period, score,
       CASE score
           WHEN 1 THEN 'Не виконано ключові цілі періоду. Рекомендовано план покращення (PIP).'
           WHEN 2 THEN 'Цілі виконано частково, є проблеми з дотриманням термінів.'
           WHEN 3 THEN 'Обов''язки виконує в повному обсязі, без зауважень.'
           WHEN 4 THEN 'Стабільно високий результат, проявляє ініціативу.'
           ELSE        'Видатний результат, рекомендовано до підвищення.' END,
       pend + interval '5 days' + r * interval '20 days'
FROM x
WHERE r < 0.85
ORDER BY period, employee_id;

-- Дисциплінарні записи та заохочення (автор — працівник відділу кадрів)
WITH x AS MATERIALIZED (
    SELECT 1 + floor(random() * 150)::int AS eid,
           floor(random() * 10)::int      AS k,
           random() AS r, random() AS r2
    FROM generate_series(1, 45)
)
INSERT INTO disciplinary_notes (employee_id, author_id, note_type, note_text, created_at)
SELECT e.employee_id,
       CASE WHEN x.r2 < 0.5 THEN 1 ELSE 2 END,
       t.note_type, t.note_text,
       greatest(e.hire_date, current_date - 700)
           + floor(x.r * (coalesce(e.dismissal_date, current_date)
                          - greatest(e.hire_date, current_date - 700)))::int
           + interval '10 hours'
FROM x
JOIN employees e ON e.employee_id = x.eid
JOIN (VALUES
    (0, 'warning',       'Систематичні запізнення: тричі за місяць понад 30 хв. Проведено бесіду.'),
    (1, 'warning',       'Порушення політики ІБ: пароль до корпоративної пошти передано колезі.'),
    (2, 'reprimand',     'Догана: прогул без поважних причин (відсутність на роботі понад 3 год).'),
    (3, 'reprimand',     'Догана: розголошення комерційної інформації в публічному чаті.'),
    (4, 'commendation',  'Подяка за успішний запуск нової версії продукту в стислі терміни.'),
    (5, 'commendation',  'Подяка за наставництво нових працівників.'),
    (6, 'commendation',  'Відзначено за найкращі показники продажів кварталу.'),
    (7, 'investigation', 'Службове розслідування: втрата корпоративного ноутбука з незашифрованим диском.'),
    (8, 'investigation', 'Службове розслідування: скарга колеги на некоректну поведінку.'),
    (9, 'warning',       'Порушення графіка чергувань у вихідні дні.')
) AS t(k, note_type, note_text) ON t.k = x.k
WHERE e.employee_id NOT IN (1, 2);

DROP TABLE _n;

-- Контроль
SELECT 'departments' AS t, count(*) FROM departments UNION ALL
SELECT 'positions',          count(*) FROM positions          UNION ALL
SELECT 'employees',          count(*) FROM employees          UNION ALL
SELECT 'salaries',           count(*) FROM salaries           UNION ALL
SELECT 'payroll',            count(*) FROM payroll            UNION ALL
SELECT 'leave_requests',     count(*) FROM leave_requests     UNION ALL
SELECT 'performance_reviews',count(*) FROM performance_reviews UNION ALL
SELECT 'disciplinary_notes', count(*) FROM disciplinary_notes;
