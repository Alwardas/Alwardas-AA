-- Migration: Update Curriculum Feedback Schema
-- Description: Adds rating and issue_type to student_curriculum_feedback

ALTER TABLE student_curriculum_feedback 
ADD COLUMN IF NOT EXISTS rating INTEGER,
ADD COLUMN IF NOT EXISTS issue_type TEXT;

-- Understood can be derived from rating or issue_type, but keeping it for backward compatibility if needed.
-- Or we can just use rating/issue_type.
