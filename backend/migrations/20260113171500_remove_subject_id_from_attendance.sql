-- Remove subject_id column as per user simplification request
ALTER TABLE attendance DROP COLUMN IF EXISTS subject_id;
