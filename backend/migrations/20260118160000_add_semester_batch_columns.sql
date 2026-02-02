-- Add semester and batch_no columns to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS semester VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS batch_no VARCHAR(50);
