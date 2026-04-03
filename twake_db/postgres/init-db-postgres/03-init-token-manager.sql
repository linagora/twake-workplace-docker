SELECT 'CREATE DATABASE token_manager'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'token_manager')\gexec
