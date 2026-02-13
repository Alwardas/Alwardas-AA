CREATE TABLE IF NOT EXISTS announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    type VARCHAR(50) NOT NULL, -- 'exam', 'event', 'faculty', 'urgent'
    audience TEXT[] NOT NULL, -- Array of strings e.g., {'Students', 'Faculty'}
    priority VARCHAR(50) NOT NULL, -- 'normal', 'important', 'urgent'
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    attachment_url VARCHAR(255),
    creator_id UUID NOT NULL
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_announcements_audience ON announcements USING GIN (audience);
CREATE INDEX IF NOT EXISTS idx_announcements_created_at ON announcements (created_at DESC);
