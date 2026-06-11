-- Create tables for ERP Connect Messenger

CREATE TABLE IF NOT EXISTS chat_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id TEXT NOT NULL REFERENCES users(login_id) ON DELETE CASCADE,
    receiver_id TEXT NOT NULL REFERENCES users(login_id) ON DELETE CASCADE,
    optional_message TEXT,
    status TEXT NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'ACCEPTED', 'REJECTED'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_sender_receiver UNIQUE (sender_id, receiver_id)
);

CREATE TABLE IF NOT EXISTS chat_groups (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    icon_url TEXT,
    created_by TEXT NOT NULL REFERENCES users(login_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chat_group_members (
    group_id TEXT NOT NULL REFERENCES chat_groups(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(login_id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'MEMBER', -- 'MEMBER', 'ADMIN'
    PRIMARY KEY (group_id, user_id)
);

CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id TEXT NOT NULL REFERENCES users(login_id) ON DELETE CASCADE,
    receiver_id TEXT NOT NULL, -- login_id of recipient OR group_id
    content TEXT NOT NULL,
    message_type TEXT NOT NULL DEFAULT 'TEXT', -- 'TEXT', 'VOICE', 'IMAGE', 'FILE', 'ERP_DOC'
    attachment_url TEXT,
    attachment_name TEXT,
    attachment_size TEXT,
    reply_to_id UUID,
    reply_to_content TEXT,
    is_starred BOOLEAN NOT NULL DEFAULT FALSE,
    is_deleted_for_everyone BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chat_blocks (
    blocker_id TEXT NOT NULL REFERENCES users(login_id) ON DELETE CASCADE,
    blocked_id TEXT NOT NULL REFERENCES users(login_id) ON DELETE CASCADE,
    PRIMARY KEY (blocker_id, blocked_id)
);
