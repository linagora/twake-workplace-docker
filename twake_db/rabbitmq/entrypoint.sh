#!/bin/bash
set -e

# Wait until RabbitMQ server is up before running rabbitmqctl
# Start RabbitMQ in background
rabbitmq-server -detached

# Wait for RabbitMQ to be ready (instead of fixed sleep)
until rabbitmqctl status >/dev/null 2>&1; do
    echo "Waiting for RabbitMQ..."
    sleep 2
done

# Add vhost, permissions, tags
rabbitmqctl add_vhost tmail || true
rabbitmqctl set_permissions -p tmail guest ".*" ".*" ".*"
rabbitmqctl set_user_tags guest administrator

# Stop the detached instance and run in foreground
rabbitmqctl stop
exec rabbitmq-server
