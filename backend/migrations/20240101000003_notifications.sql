-- Create the notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL,         -- 'USER_APPROVAL', 'PROFILE_UPDATE_REQUEST', etc.
    message TEXT NOT NULL,
    sender_id TEXT,             -- login_id of the requester
    branch TEXT,                -- branch for filtering (e.g. Computer Engineering)
    status TEXT DEFAULT 'UNREAD', -- 'UNREAD', 'ACCEPTED', 'REJECTED'
    created_at TIMESTAMPTZ DEFAULT NOW()
);
