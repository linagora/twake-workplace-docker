-- Idempotent: run on every `up` by db-ensure. La Suite Docs migrates its schema.
SELECT 'CREATE USER docs PASSWORD ''docs'''
  WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'docs')\gexec
SELECT 'CREATE DATABASE docs OWNER docs'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'docs')\gexec
