ALTER TABLE lesson_plan_feedback 
ADD COLUMN reply TEXT,
ADD COLUMN replied_at TIMESTAMPTZ,
ADD COLUMN replied_by UUID;
