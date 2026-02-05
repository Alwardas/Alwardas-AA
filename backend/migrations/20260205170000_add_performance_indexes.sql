-- Index for fast student lookup by class
CREATE INDEX IF NOT EXISTS idx_users_class_lookup 
ON users (branch, year, section, role);

-- Index for fast attendance checking
CREATE INDEX IF NOT EXISTS idx_attendance_lookup 
ON attendance (branch, year, date, session, section);

-- Index for student_uuid in attendance (joins)
CREATE INDEX IF NOT EXISTS idx_attendance_student_uuid 
ON attendance (student_uuid);
