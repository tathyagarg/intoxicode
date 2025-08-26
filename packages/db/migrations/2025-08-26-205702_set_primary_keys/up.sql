CREATE TABLE packages_copy (
  name VARCHAR(255) NOT NULL,
  version VARCHAR(50) NOT NULL,
  description TEXT,

  author VARCHAR(255) REFERENCES users(username) ON DELETE SET NULL,
  time_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (name, version)
);

INSERT INTO packages_copy (name, version, description, author, time_created)
SELECT name, version, description, author, time_created FROM packages;

DROP TABLE packages;
ALTER TABLE packages_copy RENAME TO packages;
