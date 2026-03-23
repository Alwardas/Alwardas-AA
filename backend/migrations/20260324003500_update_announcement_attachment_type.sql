-- Change attachment_url to TEXT to support longer strings (e.g. Base64 or long paths)
ALTER TABLE announcements ALTER COLUMN attachment_url TYPE TEXT;
