-- Fix foreign key constraint to allow deletion of parents
ALTER TABLE parent_student_links 
DROP CONSTRAINT IF EXISTS parent_student_links_parent_id_fkey;

ALTER TABLE parent_student_links 
ADD CONSTRAINT parent_student_links_parent_id_fkey 
FOREIGN KEY (parent_id) 
REFERENCES users(id) 
ON DELETE CASCADE;
