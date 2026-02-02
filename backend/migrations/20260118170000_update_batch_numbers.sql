UPDATE users
SET batch_no = CONCAT('20', SUBSTRING(login_id FROM 1 FOR 2), '-20', CAST((CAST(SUBSTRING(login_id FROM 1 FOR 2) AS INTEGER) + 3) AS TEXT))
WHERE role = 'Student'
  AND login_id ~ '^\d{2}';
