-- Add short_code column to department_timings
ALTER TABLE department_timings ADD COLUMN IF NOT EXISTS short_code VARCHAR(50);
