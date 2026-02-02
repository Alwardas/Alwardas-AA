-- Create the users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT NOT NULL,
    role TEXT NOT NULL,         -- 'Student', 'Parent', 'Faculty', 'HOD', 'Principal', 'Admin'
    login_id TEXT UNIQUE NOT NULL, -- The specific ID for the role (Student ID, Faculty ID, etc.)
    password_hash TEXT NOT NULL,
    branch TEXT,                -- Null for Admin/Principal
    year TEXT,                  -- Null for everyone except Student
    phone_number TEXT,
    dob DATE,
    is_approved BOOLEAN DEFAULT FALSE, -- Approval workflow
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Separate table for approvals if we want to track who approved whom? 
-- For now, we'll keep it simple as per requirements.
