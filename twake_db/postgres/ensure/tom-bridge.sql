-- Idempotent: run on every `up` by db-ensure. tom-bridge creates its tables.
SELECT 'CREATE USER twake PASSWORD ''twake!1'''
  WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'twake')\gexec
SELECT 'CREATE DATABASE tombridge TEMPLATE template0 LOCALE ''C'' ENCODING ''UTF8'' OWNER twake'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'tombridge')\gexec
