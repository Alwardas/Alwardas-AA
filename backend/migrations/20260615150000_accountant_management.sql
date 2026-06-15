-- Migration: Add Accountant Management and Assignments
-- Date: 2026-06-15

-- Alter fee_transactions to track processed_by
ALTER TABLE fee_transactions ADD COLUMN IF NOT EXISTS processed_by UUID REFERENCES users(id);

-- Create accountant_work_assignments
CREATE TABLE IF NOT EXISTS accountant_work_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    accountant_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    assignment_type VARCHAR(100) NOT NULL,
    department VARCHAR(100) NOT NULL DEFAULT 'All',
    assigned_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(50) NOT NULL DEFAULT 'Active',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed accountant accounts
INSERT INTO users (full_name, role, login_id, password_hash, is_approved, email, phone_number, dob)
VALUES 
('Sarah Jenkins', 'Accountant', 'acc-01', 'password', true, 'sarah.j@college.edu', '9876543210', '1990-05-15'),
('Rajesh Sharma', 'Accountant', 'acc-02', 'password', true, 'rajesh.s@college.edu', '9876543211', '1988-11-20'),
('David Vance', 'Accounts Manager', 'mgr-01', 'password', true, 'david.v@college.edu', '9876543212', '1982-04-10')
ON CONFLICT (login_id) DO NOTHING;

-- Map some dummy assignments
INSERT INTO accountant_work_assignments (accountant_id, assignment_type, department, assigned_by)
SELECT 
    (SELECT id FROM users WHERE login_id = 'acc-01'),
    'Fee Collection',
    'Computer Engineering',
    (SELECT id FROM users WHERE role = 'Admin' LIMIT 1)
WHERE EXISTS (SELECT 1 FROM users WHERE login_id = 'acc-01')
ON CONFLICT DO NOTHING;

INSERT INTO accountant_work_assignments (accountant_id, assignment_type, department, assigned_by)
SELECT 
    (SELECT id FROM users WHERE login_id = 'acc-02'),
    'Refund Processing',
    'Electronics & Communication Engineering',
    (SELECT id FROM users WHERE role = 'Admin' LIMIT 1)
WHERE EXISTS (SELECT 1 FROM users WHERE login_id = 'acc-02')
ON CONFLICT DO NOTHING;
