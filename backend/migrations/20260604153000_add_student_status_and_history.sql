-- 1. Add status and admission_year to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Active';
ALTER TABLE users ADD COLUMN IF NOT EXISTS admission_year INTEGER;

-- 2. Create academic_years table (optional but good for referential integrity)
CREATE TABLE IF NOT EXISTS academic_years (
    id SERIAL PRIMARY KEY,
    year_name TEXT NOT NULL UNIQUE
);

-- 3. Create student_academic_history table
CREATE TABLE IF NOT EXISTS student_academic_history (
    id SERIAL PRIMARY KEY,
    student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    academic_year TEXT NOT NULL,
    study_year TEXT NOT NULL,
    semester TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_academic_history_student ON student_academic_history(student_id);
