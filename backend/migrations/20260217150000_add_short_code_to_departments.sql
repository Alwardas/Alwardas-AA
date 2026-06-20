CREATE TABLE IF NOT EXISTS department_timings (
    branch TEXT PRIMARY KEY,
    start_hour INT NOT NULL DEFAULT 9,
    start_minute INT NOT NULL DEFAULT 0,
    class_duration INT NOT NULL DEFAULT 50,
    short_break_duration INT NOT NULL DEFAULT 10,
    lunch_duration INT NOT NULL DEFAULT 50,
    slot_config JSONB DEFAULT NULL
);

-- Add short_code column to department_timings
ALTER TABLE department_timings ADD COLUMN IF NOT EXISTS short_code VARCHAR(50);
