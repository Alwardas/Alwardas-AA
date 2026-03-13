-- Recreate issues table with new structure
DO $$ 
BEGIN 
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'issues') THEN
        IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'issues_old') THEN
            ALTER TABLE issues RENAME TO issues_old;
        ELSE
            -- If issues_old already exists, just drop the current issues table
            DROP TABLE issues CASCADE;
        END IF;
    END IF;
END $$;

CREATE TABLE issues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(100) NOT NULL, -- Academic, Attendance, Technical, Timetable, Facilities, General
    priority VARCHAR(50) NOT NULL, -- Low, Medium, High
    status VARCHAR(50) NOT NULL DEFAULT 'Open', -- Open, In Progress, Resolved, Closed
    created_by UUID NOT NULL REFERENCES users(id),
    user_role VARCHAR(50) NOT NULL,
    assigned_to UUID REFERENCES users(id),
    created_date TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE issue_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_id UUID NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
    comment TEXT NOT NULL,
    comment_by UUID NOT NULL REFERENCES users(id),
    comment_date TIMESTAMPTZ DEFAULT NOW()
);

-- Index for performance
CREATE INDEX idx_issues_created_by ON issues(created_by);
CREATE INDEX idx_issues_assigned_to ON issues(assigned_to);
CREATE INDEX idx_issue_comments_issue_id ON issue_comments(issue_id);
