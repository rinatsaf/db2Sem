INSERT INTO exam_status (name)
VALUES ('SCHEDULED'),
       ('DONE'),
       ('CANCELLED')
ON CONFLICT (name) DO NOTHING;