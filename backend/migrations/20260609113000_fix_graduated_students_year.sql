-- Fix year and semester for already graduated students
UPDATE users 
SET year = 'Graduated', semester = NULL 
WHERE role = 'Student' AND status = 'Graduated';
