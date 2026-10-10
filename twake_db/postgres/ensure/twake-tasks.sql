-- Idempotent: run on every `up` by db-ensure. Twake Tasks migrates its own
-- tables at start, as a role that is not a superuser.
SELECT 'CREATE USER twake_tasks PASSWORD ''twake_tasks'''
  WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'twake_tasks')\gexec
SELECT 'CREATE DATABASE twake_tasks OWNER twake_tasks'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'twake_tasks')\gexec
