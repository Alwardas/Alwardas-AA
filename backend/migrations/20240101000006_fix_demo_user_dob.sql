-- Fix DOB for Demo Users
UPDATE users SET dob = '2005-01-15' WHERE login_id = 'student';
UPDATE users SET dob = '1980-05-20' WHERE login_id = 'parent';
UPDATE users SET dob = '1985-08-15' WHERE login_id = 'faculty';
UPDATE users SET dob = '1975-12-10' WHERE login_id = 'hod';
UPDATE users SET dob = '1965-03-30' WHERE login_id = 'principal';
