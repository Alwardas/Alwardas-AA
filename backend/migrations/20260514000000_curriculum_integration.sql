-- Migration: Curriculum Integration Schema
-- Description: Adds tables for tracking curriculum progress and student feedback

-- 1. Curriculum Progress Table
-- Tracks completion of topics per faculty, subject, section, and semester
CREATE TABLE IF NOT EXISTS curriculum_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic_id TEXT NOT NULL,
    subject_code TEXT NOT NULL,
    faculty_id UUID NOT NULL REFERENCES users(id),
    branch TEXT NOT NULL,
    section VARCHAR(50) NOT NULL,
    year VARCHAR(50) NOT NULL,
    semester INTEGER NOT NULL,
    assigned_date DATE,
    completed_date DATE,
    status TEXT DEFAULT 'pending', -- 'pending', 'completed'
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(topic_id, subject_code, branch, section, year, semester)
);

-- 2. Student Topic Feedback Table
-- Allows students to provide feedback on specific curriculum topics
CREATE TABLE IF NOT EXISTS student_curriculum_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic_id TEXT NOT NULL,
    subject_code TEXT NOT NULL,
    student_id UUID NOT NULL REFERENCES users(id),
    understood BOOLEAN DEFAULT TRUE,
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Topic Completion Logs
-- Audit trail for when topics were marked completed
CREATE TABLE IF NOT EXISTS curriculum_completion_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    progress_id UUID REFERENCES curriculum_progress(id) ON DELETE CASCADE,
    action TEXT NOT NULL, -- 'marked_completed', 'reverted_pending'
    changed_by UUID REFERENCES users(id),
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Indices for performance
CREATE INDEX idx_curriculum_progress_lookup ON curriculum_progress(subject_code, branch, section, year);
CREATE INDEX idx_curriculum_feedback_topic ON student_curriculum_feedback(topic_id, subject_code);
