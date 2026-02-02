-- Add demo subjects for testing
INSERT INTO subjects (id, name, semester, type, branch, faculty_name) VALUES
    ('CS301', 'Software Engineering', '3rd', 'Theory', 'Computer Engineering', 'Dr. Robert Lee')
ON CONFLICT (id) DO NOTHING;

INSERT INTO subjects (id, name, semester, type, branch, faculty_name) VALUES
    ('CS302', 'Database Management', '3rd', 'Theory', 'Computer Engineering', 'Prof. Sarah Chen')
ON CONFLICT (id) DO NOTHING;

INSERT INTO subjects (id, name, semester, type, branch, faculty_name) VALUES
    ('CS303', 'Computer Networks', '3rd', 'Theory', 'Computer Engineering', 'Engr. James Wilson')
ON CONFLICT (id) DO NOTHING;

INSERT INTO subjects (id, name, semester, type, branch, faculty_name) VALUES
    ('CS304', 'Operating Systems', '3rd', 'Theory', 'Computer Engineering', 'Dr. Maria Garcia')
ON CONFLICT (id) DO NOTHING;
