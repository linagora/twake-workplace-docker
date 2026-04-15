#!/bin/bash
set -e

# ----------------------------
# Configuration: paths to repos
# ----------------------------

declare -A REPOS
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
REPOS=(
    ["twake_db"]="${BASE_DIR}/twake_db"
    ["twake_auth"]="${BASE_DIR}/twake_auth"
    ["cozy_stack"]="${BASE_DIR}/cozy_stack"
    ["linshare_app"]="${BASE_DIR}/linshare_app"
    ["onlyoffice_app"]="${BASE_DIR}/onlyoffice_app"
    ["meet_app"]="${BASE_DIR}/meet_app"
    ["calendar_app"]="${BASE_DIR}/calendar_app"
    ["chat_app"]="${BASE_DIR}/chat_app"
    ["tmail_app"]="${BASE_DIR}/tmail_app"
)

# Order of operations
START_ORDER=("twake_db" "twake_auth" "cozy_stack" "linshare_app" "onlyoffice_app" "meet_app" "calendar_app" "chat_app" "tmail_app")
STOP_ORDER=("tmail_app" "chat_app" "calendar_app" "meet_app" "onlyoffice_app" "linshare_app" "cozy_stack" "twake_auth" "twake_db")

# Dependencies: containers that must be healthy before starting a repo
declare -A REPO_DEPS
REPO_DEPS=(
    ["chat_app"]="lemonldap-ng"
    ["tmail_app"]="lemonldap-ng"
)

show_help() {
    echo "Usage: $0 <up|down> [repo] [service] [docker-compose options]"
    echo
    echo "Examples:"
    echo "  $0 up -d                        Start all repos in order"
    echo "  $0 up twake_db                  Start only the twake_db repo"
    echo "  $0 up twake_auth lemonldap      Start only the lemonldap service in twake_auth"
    echo "  $0 down                         Stop all repos in reverse order"
    echo "  $0 down cozy_stack              Stop only cozy_stack"
}

# ----------------------------
# Helper: wait for all containers in a repo to be healthy
# ----------------------------
wait_for_repo_health() {
    echo "⏳ Waiting for all containers in repo '$1' to be healthy..."

    containers=$(sudo docker compose --env-file ../.env ps -q)
    if [[ -z "$containers" ]]; then
        echo "⚠️ No containers found for $1"
        return
    fi

    for c in $containers; do
        name=$(sudo docker inspect --format '{{.Name}}' "$c" | cut -d/ -f2)

        # 👉 Skip patcher container
        if [[ "$name" == patcher-* ]]; then
            echo "ℹ️ Skipping patcher container '$name'"
            continue
        fi

        # Check if container has healthcheck
        status=$(sudo docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$c")

        if [[ -z "$status" ]]; then
            echo "ℹ️ Container '$name' has no healthcheck, skipping..."
            continue
        fi

        echo "⏳ Waiting for container '$name'..."
        local attempt=0
        local max_attempts=40
        until [[ "$(sudo docker inspect -f '{{.State.Health.Status}}' "$c")" == "healthy" ]]; do
            attempt=$((attempt + 1))
            if [[ $attempt -ge $max_attempts ]]; then
                echo "❌ Timeout waiting for '$name' to become healthy"
                sudo docker logs "$c" --tail 20 2>&1 || true
                exit 1
            fi
            sleep 3
        done
        echo "✅ '$name' is healthy!"
    done
}

# ----------------------------
# Helper: check that required containers are healthy before starting a repo
# ----------------------------
check_deps() {
    local repo=$1
    local deps="${REPO_DEPS[$repo]}"
    if [[ -z "$deps" ]]; then
        return
    fi

    for dep in $deps; do
        local status
        status=$(sudo docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$dep" 2>/dev/null || true)

        if [[ "$status" != "healthy" ]]; then
            echo "❌ Dependency '$dep' is not healthy (status: ${status:-not found}). Cannot start '$repo'."
            exit 1
        fi
        echo "✅ Dependency '$dep' is healthy"
    done
}

# ----------------------------
# Helper: run a repo
# ----------------------------
run_repo() {
    local action=$1
    local repo=$2
    local service=$3
    shift 3
    local options=("$@")

    local dir="${REPOS[$repo]}"
    if [[ -z "$dir" ]]; then
        echo "❌ Unknown repo: $repo"
        exit 1
    fi

    echo "🚀 $action '$repo' ${service:+service '$service'} ..."

    if [[ "$action" == "up" ]]; then
        check_deps "$repo"
    fi

    cd "$dir"

    # If repo has a custom wrapper script, use it
    if [[ -f "./compose-wrapper.sh" ]]; then
      if [[ -n "$service" ]]; then
        ./compose-wrapper.sh "$action" "$service" "${options[@]}"
      else
        ./compose-wrapper.sh "$action" "${options[@]}"
      fi
    else
      if [[ -n "$service" ]]; then
        sudo docker compose --env-file ../.env "$action" "${options[@]}" "$service"
      else
        sudo docker compose --env-file ../.env "$action" "${options[@]}"
      fi
    fi

    # wait for all containers in this repo (only for 'up')
    if [[ "$action" == "up" ]]; then
        wait_for_repo_health "$repo"
    fi
}

# ----------------------------
# Main
# ----------------------------
if [[ $# -lt 1 ]]; then
    show_help
    exit 1
fi

COMMAND=$1
shift

# --help support
if [[ "$COMMAND" == "-h" || "$COMMAND" == "--help" ]]; then
    show_help
    exit 0
fi

# Detect repo and service from input
TARGET_REPO=""
TARGET_SERVICE=""
DOCKER_OPTIONS=()

for arg in "$@"; do
    if [[ -n "${REPOS[$arg]}" ]]; then
        TARGET_REPO="$arg"
    elif [[ "$arg" =~ ^- ]]; then
        DOCKER_OPTIONS+=("$arg")
    else
        TARGET_SERVICE="$arg"
    fi
done

# Determine which repos to operate on
if [[ -n "$TARGET_REPO" ]]; then
    REPOS_TO_RUN=("$TARGET_REPO")
else
    if [[ "$COMMAND" == "up" ]]; then
        REPOS_TO_RUN=("${START_ORDER[@]}")
    else
        REPOS_TO_RUN=("${STOP_ORDER[@]}")
    fi
fi

# Execute each repo
for repo in "${REPOS_TO_RUN[@]}"; do
    run_repo "$COMMAND" "$repo" "$TARGET_SERVICE" "${DOCKER_OPTIONS[@]}"
done

echo "✅ Done!"