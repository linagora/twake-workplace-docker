-- Idempotent: run on every `up` by db-ensure. Twake Space migrates its own
-- tables at start, as a role that is not a superuser.
SELECT 'CREATE USER twake_space PASSWORD ''twake_space'''
  WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'twake_space')\gexec
SELECT 'CREATE DATABASE twake_space OWNER twake_space'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'twake_space')\gexec
