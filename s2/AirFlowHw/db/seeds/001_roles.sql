INSERT INTO role (code, name, status)
VALUES ('admin', 'Administrator', 'ACTIVE'),
       ('student', 'Student', 'ACTIVE'),
       ('teacher', 'Teacher', 'ACTIVE')
ON CONFLICT (code)
    DO UPDATE SET name   = EXCLUDED.name,
                  status = EXCLUDED.status;