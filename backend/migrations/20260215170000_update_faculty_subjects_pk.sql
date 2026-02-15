-- Add section column if not exists
ALTER TABLE faculty_subjects ADD COLUMN IF NOT EXISTS section TEXT DEFAULT 'Section A';

-- Drop existing primary key or unique constraint
ALTER TABLE faculty_subjects DROP CONSTRAINT IF EXISTS faculty_subjects_pkey;

-- Add new primary key including section
ALTER TABLE faculty_subjects ADD PRIMARY KEY (user_id, subject_id, section);
