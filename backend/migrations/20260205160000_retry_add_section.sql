-- Increase timeout for this transaction
SET statement_timeout = 60000;

-- Attempt to add section column again, ensuring it exists
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS section VARCHAR(50) DEFAULT 'Section A';

-- Also ensure users table has it, just in case
ALTER TABLE users ADD COLUMN IF NOT EXISTS section VARCHAR(50) DEFAULT 'Section A';
