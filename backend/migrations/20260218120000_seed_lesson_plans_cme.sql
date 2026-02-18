-- Seed Subjects (Ensure they exist)
INSERT INTO subjects (id, name, semester, type, branch) VALUES
('CM-101', 'English-I', '1st Year', 'Theory', 'Computer Engineering'),
('CM-102', 'Engineering Mathematics-I', '1st Year', 'Theory', 'Computer Engineering')
ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name,
    semester = EXCLUDED.semester,
    type = EXCLUDED.type,
    branch = EXCLUDED.branch;

-- Seed Lesson Plan Items for CM-101
INSERT INTO lesson_plan_items (id, subject_id, type, text, topic, sno, order_index) VALUES
('cm101-u1', 'CM-101', 'unit', 'UNIT 1: English for Employability', NULL, NULL, 1),
('cm101-1.1', 'CM-101', 'topic', NULL, 'Perceive the need for improving communication in English for employability', '1.1', 2),
('cm101-1.2', 'CM-101', 'topic', NULL, 'Use adjectives and articles effectively while speaking and in writing', '1.2', 3),
('cm101-1.3', 'CM-101', 'topic', NULL, 'Write simple sentences', '1.3', 4),
('cm101-u1end', 'CM-101', 'unitEnd', '(UNIT 1 END)', NULL, NULL, 5),

('cm101-u2', 'CM-101', 'unit', 'UNIT 2: Living in Harmony', NULL, NULL, 6),
('cm101-2.1', 'CM-101', 'topic', NULL, 'Develop positive self-esteem for harmonious relationships', '2.1', 7),
('cm101-2.2', 'CM-101', 'topic', NULL, 'Use affixation to form new words', '2.2', 8),
('cm101-2.3', 'CM-101', 'topic', NULL, 'Use prepositions and use a few phrasal verbs contextually', '2.3', 9),
('cm101-u2end', 'CM-101', 'unitEnd', '(UNIT 2 END)', NULL, NULL, 10),

('cm101-u3', 'CM-101', 'unit', 'UNIT 3: Connect with Care', NULL, NULL, 11),
('cm101-3.1', 'CM-101', 'topic', NULL, 'Use social media with discretion', '3.1', 12),
('cm101-3.2', 'CM-101', 'topic', NULL, 'Speak about abilities and possibilities', '3.2', 13),
('cm101-3.3', 'CM-101', 'topic', NULL, 'Make requests and express obligations', '3.3', 14),
('cm101-3.4', 'CM-101', 'topic', NULL, 'Use modal verbs and main verbs in appropriate form', '3.4', 15),
('cm101-3.5', 'CM-101', 'topic', NULL, 'Write short dialogues about everyday situations', '3.5', 16),
('cm101-u3end', 'CM-101', 'unitEnd', '(UNIT 3 END)', NULL, NULL, 17)
ON CONFLICT (id) DO NOTHING;
