CREATE TABLE IF NOT EXISTS timetables (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch VARCHAR(100) NOT NULL,
    year VARCHAR(50) NOT NULL,
    section VARCHAR(10) NOT NULL DEFAULT 'A',
    day VARCHAR(20) NOT NULL,
    period_number INT NOT NULL,
    start_time VARCHAR(20) NOT NULL,
    end_time VARCHAR(20) NOT NULL,
    subject_name VARCHAR(255) NOT NULL,
    type VARCHAR(20) DEFAULT 'class',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

DROP INDEX IF EXISTS idx_timetables_slot;
CREATE UNIQUE INDEX IF NOT EXISTS idx_timetables_slot ON timetables(branch, year, section, day, period_number);
