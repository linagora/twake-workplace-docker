#!/bin/bash
set -e

set -a
source ../.env
set +a

FILES=(-f docker-compose.yml)
if [ -n "${TWAKE_SPACE_MATRIX_AS_TOKEN:-}" ]; then
  FILES+=(-f docker-compose.chat.yml)
fi

sudo docker compose --env-file ../.env "${FILES[@]}" "$@"
