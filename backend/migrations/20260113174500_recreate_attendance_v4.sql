-- Drop the old table completely to start fresh
DROP TABLE IF EXISTS attendance CASCADE;

-- Recreate with human-friendly columns explicitly prioritized
CREATE TABLE attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Human Readable Identifiers (The priority)
    student_name VARCHAR(150),
    student_login_id VARCHAR(50), -- e.g. 24634-CM-001
    faculty_name VARCHAR(150),
    
    -- Organization
    branch VARCHAR(50), -- e.g. CME
    year VARCHAR(20),   -- e.g. 1st Year
    session VARCHAR(20), -- MORNING / AFTERNOON
    
    -- Core Data
    date DATE NOT NULL,
    status VARCHAR(10) NOT NULL, -- 'P' or 'A'
    
    -- Links (Still kept for code integrity, but nullable if you want pure text flexibility)
    -- We keep them NOT NULL to ensure the app doesn't break, but they are less prominent
    student_uuid UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    faculty_uuid UUID NOT NULL REFERENCES users(id),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Enforce uniqueness per session
    CONSTRAINT attendance_student_session_unique UNIQUE (student_login_id, date, session)
);

-- Indexes for fast searching by name/id
CREATE INDEX idx_att_student_login ON attendance(student_login_id);
CREATE INDEX idx_att_date ON attendance(date);
