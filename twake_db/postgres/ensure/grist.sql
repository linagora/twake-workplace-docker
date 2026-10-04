-- Idempotent: run on every `up` by db-ensure. Grist creates its tables.
SELECT 'CREATE USER grist PASSWORD ''grist'''
  WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'grist')\gexec
SELECT 'CREATE DATABASE grist OWNER grist'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'grist')\gexec
