-- Schema for the nixpkgs package search index (Cloudflare D1 / SQLite).
--
-- `packages` holds one row per nixpkgs attribute; `packages_fts` is an
-- external-content FTS5 index over the searchable columns. After bulk-loading
-- rows into `packages`, the FTS index is (re)built with:
--
--   INSERT INTO packages_fts(packages_fts) VALUES('rebuild');
--
-- The full data file produced by build-nixpkgs-index.sh includes this schema,
-- the INSERT statements, and the rebuild, so `wrangler d1 execute --file
-- nixpkgs.sql` recreates the index from scratch each run.

DROP TABLE IF EXISTS packages_fts;
DROP TABLE IF EXISTS packages;

CREATE TABLE packages (
  attr_name    TEXT PRIMARY KEY,
  pname        TEXT,
  version      TEXT,
  description  TEXT,
  homepage     TEXT,
  license      TEXT,
  main_program TEXT,
  unfree       INTEGER DEFAULT 0
);

CREATE VIRTUAL TABLE packages_fts USING fts5(
  attr_name,
  pname,
  description,
  content='packages',
  content_rowid='rowid'
);
