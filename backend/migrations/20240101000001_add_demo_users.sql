-- Add Demo Users (All Approved)
INSERT INTO users (full_name, role, login_id, password_hash, branch, year, phone_number, is_approved) VALUES
('Demo Student', 'Student', 'student', '123', 'Computer Engineering', '1st Year', '9999999999', TRUE),
('Demo Parent', 'Parent', 'parent', '123', 'Computer Engineering', NULL, '9999999998', TRUE),
('Demo Faculty', 'Faculty', 'faculty', '123', 'Computer Engineering', NULL, '9999999997', TRUE),
('Demo HOD', 'HOD', 'hod', '123', 'Computer Engineering', NULL, '9999999996', TRUE),
('Demo Principal', 'Principal', 'principal', '123', NULL, NULL, '9999999995', TRUE),
('Demo Admin', 'Admin', 'admin', '123', NULL, NULL, '9999999994', TRUE)
ON CONFLICT (login_id) DO NOTHING;
