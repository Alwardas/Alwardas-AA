-- Create subjects table
CREATE TABLE IF NOT EXISTS subjects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    semester TEXT NOT NULL,
    type TEXT NOT NULL,
    branch TEXT NOT NULL,
    faculty_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create lesson_plan_items table
CREATE TABLE IF NOT EXISTS lesson_plan_items (
    id TEXT PRIMARY KEY,
    subject_id TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    text TEXT,
    topic TEXT,
    sno TEXT,
    order_index INTEGER NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    completed_date TIMESTAMPTZ,
    target_date TIMESTAMPTZ,
    review TEXT,
    student_review TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
