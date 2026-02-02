-- Add organization columns for easier backend management
ALTER TABLE attendance 
ADD COLUMN branch VARCHAR(50),
ADD COLUMN year VARCHAR(20),
ADD COLUMN session VARCHAR(20) DEFAULT 'MORNING';

-- Remove old uniqueness constraint (was per day)
ALTER TABLE attendance DROP CONSTRAINT IF EXISTS attendance_student_id_date_key;

-- Add new uniqueness constraint (per session per day)
-- This allows separate Morning/Afternoon entries
ALTER TABLE attendance 
ADD CONSTRAINT attendance_student_id_date_session_key UNIQUE (student_id, date, session);
