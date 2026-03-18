-- Идемпотентные пользователи для тестов
INSERT INTO service.users(full_name, email, phone_number)
VALUES
    ('Alice Doe','alice@example.com','+15551230001'),
    ('Bob Smith','bob@example.com','+15551230002'),
    ('Carol Jones','carol@example.com','+15551230003')
ON CONFLICT (email) DO UPDATE
SET full_name = EXCLUDED.full_name,
    phone_number = EXCLUDED.phone_number;
