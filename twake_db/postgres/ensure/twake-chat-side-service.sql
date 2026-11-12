-- Idempotent: run on every `up` by db-ensure. twake-chat-side-service
-- creates its table at start, as the owner of the database.
SELECT 'CREATE USER twake_chat_side_service PASSWORD ''twake_chat_side_service'''
  WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'twake_chat_side_service')\gexec
SELECT 'CREATE DATABASE twake_chat_side_service OWNER twake_chat_side_service'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'twake_chat_side_service')\gexec
