CREATE TABLE IF NOT EXISTS faculty_subjects (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    subject_id TEXT REFERENCES subjects(id) ON DELETE CASCADE,
    subject_name TEXT, -- Cache for display if needed
    branch TEXT,
    status TEXT DEFAULT 'APPROVED', -- PENDING, APPROVED, REJECTED
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, subject_id)
);
