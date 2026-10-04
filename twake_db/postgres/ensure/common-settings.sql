-- Idempotent: run on every `up` by db-ensure, so existing volumes get it too.
SELECT 'CREATE USER common_settings PASSWORD ''common_settings'''
  WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'common_settings')\gexec
SELECT 'CREATE DATABASE common_settings OWNER common_settings'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'common_settings')\gexec

\connect common_settings
SET ROLE common_settings;
-- Schema of src/lib/server/db/schema.ts; the image does not migrate on start.
CREATE TABLE IF NOT EXISTS user_settings (
  nickname text PRIMARY KEY,
  settings jsonb NOT NULL,
  version integer NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS nickname_idx ON user_settings (nickname);
