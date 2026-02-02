-- Add human-readable columns to attendance table for easier direct DB management
ALTER TABLE attendance 
ADD COLUMN student_name VARCHAR(100),
ADD COLUMN student_login_id VARCHAR(50),
ADD COLUMN faculty_name VARCHAR(100);
