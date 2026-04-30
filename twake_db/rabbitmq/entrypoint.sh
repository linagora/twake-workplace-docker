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

# Declare topic exchanges listed in RABBITMQ_DECLARE_EXCHANGES (comma-separated).
# Used for exchanges that downstream services expect to pre-exist instead of
# declaring themselves. Idempotent: re-running with matching params is a no-op.
if [ -n "${RABBITMQ_DECLARE_EXCHANGES:-}" ]; then
    # rabbitmqadmin needs the management HTTP API
    for _ in $(seq 1 30); do
        if rabbitmqadmin list users >/dev/null 2>&1; then
            break
        fi
        echo "Waiting for RabbitMQ management API..."
        sleep 2
    done

    IFS=',' read -ra EXCHANGES <<< "$RABBITMQ_DECLARE_EXCHANGES"
    for exchange in "${EXCHANGES[@]}"; do
        exchange="$(echo -n "$exchange" | tr -d '[:space:]')"
        [ -z "$exchange" ] && continue
        rabbitmqadmin declare exchange \
            name="$exchange" type=topic durable=true auto_delete=false internal=false
    done
fi

# Stop the detached instance and run in foreground
rabbitmqctl stop
exec rabbitmq-server
