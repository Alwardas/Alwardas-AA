-- Add recipient_id to notifications for targeted messages
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS recipient_id TEXT;

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_id ON notifications(recipient_id);
