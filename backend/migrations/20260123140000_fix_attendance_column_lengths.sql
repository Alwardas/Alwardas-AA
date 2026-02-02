-- Increase column lengths for attendance table to prevent "value too long" errors
ALTER TABLE attendance ALTER COLUMN branch TYPE VARCHAR(255);
ALTER TABLE attendance ALTER COLUMN year TYPE VARCHAR(100);
ALTER TABLE attendance ALTER COLUMN session TYPE VARCHAR(100);
ALTER TABLE attendance ALTER COLUMN status TYPE VARCHAR(50);
ALTER TABLE attendance ALTER COLUMN student_name TYPE VARCHAR(255);
ALTER TABLE attendance ALTER COLUMN student_login_id TYPE VARCHAR(100);
ALTER TABLE attendance ALTER COLUMN faculty_name TYPE VARCHAR(255);
