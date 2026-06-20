CREATE TABLE IF NOT EXISTS lesson_schedule (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_id TEXT NOT NULL,
    topic_id TEXT NOT NULL,
    schedule_date TIMESTAMPTZ,
    faculty_id TEXT,
    branch TEXT NOT NULL,
    year TEXT NOT NULL,
    semester TEXT NOT NULL,
    UNIQUE(subject_id, topic_id)
);

-- Migration to fix lesson_schedule date type and constraints
ALTER TABLE lesson_schedule ALTER COLUMN schedule_date TYPE DATE USING schedule_date::date;

-- Add missing section column to lesson_schedule if not exists
ALTER TABLE lesson_schedule ADD COLUMN IF NOT EXISTS section VARCHAR(50) DEFAULT 'Section A';

-- Drop old unique constraint if it was just (subject_id, topic_id)
ALTER TABLE lesson_schedule DROP CONSTRAINT IF EXISTS lesson_schedule_subject_id_topic_id_key;
ALTER TABLE lesson_schedule DROP CONSTRAINT IF EXISTS lesson_schedule_unique_booking;

-- Add comprehensive unique constraint for syllabus scheduling
-- A syllabus item (topic) can be scheduled differently for different branches/sections
ALTER TABLE lesson_schedule ADD CONSTRAINT lesson_schedule_unique_booking UNIQUE (subject_id, topic_id, section, branch);
