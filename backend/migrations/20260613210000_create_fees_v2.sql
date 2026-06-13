-- Migration: Create Fee Transparency System tables
-- Date: 2026-06-13

-- 1. Create fee categories
CREATE TABLE IF NOT EXISTS fee_categories (
    name VARCHAR(50) PRIMARY KEY,
    description TEXT
);

-- Seed fee categories
INSERT INTO fee_categories (name, description) VALUES
('Tuition Fee', 'Base instructional fee for academic courses'),
('Lab Fee', 'Charges for utilization of science, computer, and research laboratories'),
('Library Fee', 'Charges for accessing physical and electronic library resources'),
('Exam Fee', 'University examination registration and processing charges'),
('Transport Fee', 'College bus facility subscription charges'),
('Hostel Fee', 'Boarding and lodging charges for residential students'),
('Miscellaneous Fee', 'Other administrative, sports, and cultural activity fees')
ON CONFLICT (name) DO NOTHING;

-- 2. Create fee structures by branch and year
CREATE TABLE IF NOT EXISTS fee_structures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch VARCHAR(100) NOT NULL,
    year VARCHAR(50) NOT NULL,
    category VARCHAR(50) NOT NULL REFERENCES fee_categories(name) ON UPDATE CASCADE,
    amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(branch, year, category)
);

-- Seed default structures for Computer Engineering and other branches
INSERT INTO fee_structures (branch, year, category, amount) VALUES
-- CME 1st Year
('Computer Engineering', '1st Year', 'Tuition Fee', 50000.00),
('Computer Engineering', '1st Year', 'Lab Fee', 10000.00),
('Computer Engineering', '1st Year', 'Library Fee', 5000.00),
('Computer Engineering', '1st Year', 'Exam Fee', 3000.00),
('Computer Engineering', '1st Year', 'Transport Fee', 15000.00),
('Computer Engineering', '1st Year', 'Hostel Fee', 25000.00),
('Computer Engineering', '1st Year', 'Miscellaneous Fee', 5000.00),
-- CME 2nd Year
('Computer Engineering', '2nd Year', 'Tuition Fee', 52000.00),
('Computer Engineering', '2nd Year', 'Lab Fee', 10000.00),
('Computer Engineering', '2nd Year', 'Library Fee', 5000.00),
('Computer Engineering', '2nd Year', 'Exam Fee', 3000.00),
('Computer Engineering', '2nd Year', 'Transport Fee', 16000.00),
('Computer Engineering', '2nd Year', 'Hostel Fee', 26000.00),
('Computer Engineering', '2nd Year', 'Miscellaneous Fee', 5000.00),
-- CME 3rd Year
('Computer Engineering', '3rd Year', 'Tuition Fee', 55000.00),
('Computer Engineering', '3rd Year', 'Lab Fee', 10000.00),
('Computer Engineering', '3rd Year', 'Library Fee', 5000.00),
('Computer Engineering', '3rd Year', 'Exam Fee', 3000.00),
('Computer Engineering', '3rd Year', 'Transport Fee', 17000.00),
('Computer Engineering', '3rd Year', 'Hostel Fee', 27000.00),
('Computer Engineering', '3rd Year', 'Miscellaneous Fee', 5000.00),
-- Electronics & Communication Engineering
('Electronics & Communication Engineering', '1st Year', 'Tuition Fee', 48000.00),
('Electronics & Communication Engineering', '1st Year', 'Lab Fee', 8000.00),
('Electronics & Communication Engineering', '1st Year', 'Library Fee', 4000.00),
('Electronics & Communication Engineering', '1st Year', 'Exam Fee', 3000.00),
('Electronics & Communication Engineering', '1st Year', 'Transport Fee', 15000.00),
('Electronics & Communication Engineering', '1st Year', 'Hostel Fee', 25000.00),
('Electronics & Communication Engineering', '1st Year', 'Miscellaneous Fee', 4000.00)
ON CONFLICT (branch, year, category) DO NOTHING;

-- 3. Create student_fees table
CREATE TABLE IF NOT EXISTS student_fees (
    student_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    total_fee NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    paid_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    scholarship_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    fine_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    status VARCHAR(50) NOT NULL DEFAULT 'Unpaid',
    last_payment_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Create fee_details table
CREATE TABLE IF NOT EXISTS fee_details (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category VARCHAR(50) NOT NULL REFERENCES fee_categories(name) ON UPDATE CASCADE,
    amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    scholarship NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    fine NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    remarks TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(student_id, category)
);

-- 5. Create fee_transactions table
CREATE TABLE IF NOT EXISTS fee_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_number VARCHAR(100) UNIQUE NOT NULL,
    student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount NUMERIC(12, 2) NOT NULL,
    payment_mode VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'Success',
    transaction_date TIMESTAMPTZ DEFAULT NOW(),
    reference_number VARCHAR(100),
    remarks TEXT
);

-- Create index for quick search
CREATE INDEX IF NOT EXISTS idx_fee_transactions_student ON fee_transactions(student_id);

-- 6. Create fee_change_history table
CREATE TABLE IF NOT EXISTS fee_change_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category VARCHAR(50) NOT NULL REFERENCES fee_categories(name) ON UPDATE CASCADE,
    previous_amount NUMERIC(12, 2) NOT NULL,
    new_amount NUMERIC(12, 2) NOT NULL,
    reason TEXT NOT NULL,
    updated_by UUID NOT NULL REFERENCES users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fee_change_history_student ON fee_change_history(student_id);

-- 7. Create approval_workflows table
CREATE TABLE IF NOT EXISTS approval_workflows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'Pending_Admin',
    created_by UUID NOT NULL REFERENCES users(id),
    approved_by_admin UUID REFERENCES users(id),
    approved_by_principal UUID REFERENCES users(id),
    rejected_by UUID REFERENCES users(id),
    rejection_reason TEXT,
    student_count INT NOT NULL DEFAULT 0,
    total_difference NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    reason TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Create audit_trails table (immutable, soft deletes not allowed, role-based logs)
CREATE TABLE IF NOT EXISTS audit_trails (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_id UUID REFERENCES approval_workflows(id) ON DELETE SET NULL,
    operation_type VARCHAR(100) NOT NULL,
    student_count INT NOT NULL DEFAULT 0,
    created_by UUID NOT NULL REFERENCES users(id),
    approved_by UUID REFERENCES users(id),
    reason TEXT NOT NULL,
    ip_address VARCHAR(45),
    status VARCHAR(50) NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Seed initial records for existing students in the database
DO $$
DECLARE
    r RECORD;
    b_fee NUMERIC(12, 2);
    cat RECORD;
    t_fee NUMERIC(12, 2);
BEGIN
    FOR r IN SELECT id, branch, year FROM users WHERE role = 'Student' LOOP
        -- check if student has fees initialized
        IF NOT EXISTS (SELECT 1 FROM student_fees WHERE student_id = r.id) THEN
            t_fee := 0;
            -- add fee categories
            FOR cat IN SELECT name FROM fee_categories LOOP
                -- resolve base fee from fee_structures or use defaults
                SELECT amount INTO b_fee FROM fee_structures 
                WHERE branch = r.branch AND year = r.year AND category = cat.name;
                
                IF b_fee IS NULL THEN
                    b_fee := CASE 
                        WHEN cat.name = 'Tuition Fee' THEN 50000.00
                        WHEN cat.name = 'Lab Fee' THEN 5000.00
                        WHEN cat.name = 'Library Fee' THEN 3000.00
                        WHEN cat.name = 'Exam Fee' THEN 2000.00
                        ELSE 0.00
                    END;
                END IF;
                
                INSERT INTO fee_details (student_id, category, amount, scholarship, fine, remarks)
                VALUES (r.id, cat.name, b_fee, 0.00, 0.00, 'Initial base structure setup')
                ON CONFLICT (student_id, category) DO NOTHING;
                
                t_fee := t_fee + b_fee;
            END LOOP;
            
            INSERT INTO student_fees (student_id, total_fee, paid_amount, scholarship_amount, fine_amount, status)
            VALUES (r.id, t_fee, 0.00, 0.00, 0.00, 'Unpaid')
            ON CONFLICT (student_id) DO NOTHING;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
