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

# Wait for the management HTTP API (rabbitmqadmin uses it)
for _ in $(seq 1 30); do
    if rabbitmqadmin list users >/dev/null 2>&1; then
        break
    fi
    echo "Waiting for RabbitMQ management API..."
    sleep 2
done

# Declare topic exchanges that cozy-stack expects to pre-exist
# (its rabbitmq config sets declare_exchange: false). These carry the
# B2B contact sync events emitted by ldap-rest:
#   - auth: routing key user.created
#   - b2b:  routing key domain.user.deleted
# Idempotent: re-running with matching params is a no-op.
for exchange in auth b2b; do
    rabbitmqadmin declare exchange \
        name="${exchange}" type=topic durable=true auto_delete=false internal=false
done

# Stop the detached instance and run in foreground
rabbitmqctl stop
exec rabbitmq-server
