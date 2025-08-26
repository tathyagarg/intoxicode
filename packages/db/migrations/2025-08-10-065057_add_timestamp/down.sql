-- This file should undo anything in `up.sql`
ALTER TABLE packages
DROP COLUMN time_created;
