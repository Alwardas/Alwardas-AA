-- Add lesson_plan_progress table
CREATE TABLE IF NOT EXISTS lesson_plan_progress (
    item_id TEXT REFERENCES lesson_plan_items(id) ON DELETE CASCADE,
    section VARCHAR(50),
    completed BOOLEAN DEFAULT FALSE,
    completed_date TIMESTAMPTZ,
    PRIMARY KEY (item_id, section)
);
