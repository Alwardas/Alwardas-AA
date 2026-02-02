-- Create lesson_plan_feedback table
CREATE TABLE IF NOT EXISTS lesson_plan_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lesson_plan_item_id TEXT NOT NULL REFERENCES lesson_plan_items(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rating INTEGER,
    issue_type TEXT,
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
