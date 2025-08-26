ALTER TABLE packages
ADD COLUMN time_created;

UPDATE packages SET time_created = CURRENT_TIMESTAMP
WHERE time_created IS NULL;
