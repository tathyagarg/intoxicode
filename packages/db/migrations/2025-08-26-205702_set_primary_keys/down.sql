-- This file should undo anything in `up.sql`
CREATE TABLE packages_copy (
  name VARCHAR(255) NOT NULL UNIQUE,
  version VARCHAR(50) NOT NULL,
  description TEXT,
);

INSERT INTO packages_copy (name, version, description)
SELECT name, version, description FROM packages;

DROP TABLE packages;
ALTER TABLE packages_copy RENAME TO packages;
