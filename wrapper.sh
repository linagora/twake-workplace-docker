#!/bin/bash
set -e

# ----------------------------
# Configuration
# ----------------------------

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# All known repos
ALL_REPOS="twake_db twake_auth drive_app onlyoffice_app visio_app calendar_app chat_app mail_app token_manager"

# Order of operations
START_ORDER="twake_db twake_auth drive_app token_manager onlyoffice_app visio_app calendar_app chat_app mail_app"
STOP_ORDER="mail_app chat_app calendar_app visio_app onlyoffice_app token_manager drive_app twake_auth twake_db"

# Lookup helpers (Bash 3 compatible, no associative arrays)
get_project_name() {
    case "$1" in
        twake_db)       echo "twake-db" ;;
        twake_auth)     echo "twake-auth" ;;
        drive_app)      echo "twake-drive" ;;
        onlyoffice_app) echo "twake-onlyoffice" ;;
        visio_app)      echo "twake-visio" ;;
        calendar_app)   echo "twake-calendar" ;;
        chat_app)       echo "twake-chat" ;;
        mail_app)       echo "twake-mail" ;;
        *)              echo "" ;;
    esac
}

get_repo_dir() {
    echo "${BASE_DIR}/$1"
}

get_dep() {
    case "$1" in
        chat_app)      echo "lemonldap-ng" ;;
        mail_app)      echo "lemonldap-ng" ;;
        token_manager) echo "lemonldap-ng" ;;
        *)             echo "" ;;
    esac
}

is_known_repo() {
    for r in $ALL_REPOS; do
        if [ "$r" = "$1" ]; then
            return 0
        fi
    done
    return 1
}

show_help() {
    echo "Usage: $0 <up|down> [repo] [service] [docker-compose options]"
    echo
    echo "Examples:"
    echo "  $0 up -d                        Start all repos in order"
    echo "  $0 up twake_db                  Start only the twake_db repo"
    echo "  $0 up twake_auth lemonldap      Start only the lemonldap service in twake_auth"
    echo "  $0 down                         Stop all repos in reverse order"
    echo "  $0 down drive_app               Stop only drive_app"
    echo
    echo "Available repos:"
    echo "  $ALL_REPOS"
}

# ----------------------------
# Helper: wait for all containers in a repo to be healthy
# ----------------------------
wait_for_repo_health() {
    local repo="$1"
    local project
    project="$(get_project_name "$repo")"

    echo "⏳ Waiting for all containers in repo '$repo' to be healthy..."

    containers=$(sudo docker compose -p "$project" --env-file ../.env ps -q)
    if [ -z "$containers" ]; then
        echo "⚠️ No containers found for $repo"
        return
    fi

    for c in $containers; do
        name=$(sudo docker inspect --format '{{.Name}}' "$c" | cut -d/ -f2)

        # Skip patcher container
        if echo "$name" | grep -q '^patcher-'; then
            echo "ℹ️ Skipping patcher container '$name'"
            continue
        fi

        # Check if container has healthcheck
        status=$(sudo docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$c")

        if [ -z "$status" ]; then
            echo "ℹ️ Container '$name' has no healthcheck, skipping..."
            continue
        fi

        echo "⏳ Waiting for container '$name'..."
        attempt=0
        max_attempts=40
        while [ "$(sudo docker inspect -f '{{.State.Health.Status}}' "$c")" != "healthy" ]; do
            attempt=$((attempt + 1))
            if [ $attempt -ge $max_attempts ]; then
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
    local repo="$1"
    local deps
    deps="$(get_dep "$repo")"
    if [ -z "$deps" ]; then
        return
    fi

    for dep in $deps; do
        status=$(sudo docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$dep" 2>/dev/null || true)

        if [ "$status" != "healthy" ]; then
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
    local action="$1"
    local repo="$2"
    local service="$3"
    shift 3

    local dir
    dir="$(get_repo_dir "$repo")"
    local project
    project="$(get_project_name "$repo")"

    if [ ! -d "$dir" ]; then
        echo "❌ Unknown repo: $repo"
        exit 1
    fi

    echo "🚀 $action '$repo' ${service:+service '$service'} ..."

    if [ "$action" = "up" ]; then
        check_deps "$repo"
    fi

    cd "$dir"

    # If repo has a custom wrapper script, use it
    if [ -f "./compose-wrapper.sh" ]; then
        if [ -n "$service" ]; then
            ./compose-wrapper.sh "$action" "$service" "$@"
        else
            ./compose-wrapper.sh "$action" "$@"
        fi
    else
        if [ -n "$service" ]; then
            sudo docker compose -p "$project" --env-file ../.env "$action" "$@" "$service"
        else
            sudo docker compose -p "$project" --env-file ../.env "$action" "$@"
        fi
    fi

    # wait for all containers in this repo (only for 'up')
    if [ "$action" = "up" ]; then
        wait_for_repo_health "$repo"
    fi
}

# ----------------------------
# Main
# ----------------------------
if [ $# -lt 1 ]; then
    show_help
    exit 1
fi

COMMAND="$1"
shift

# --help support
if [ "$COMMAND" = "-h" ] || [ "$COMMAND" = "--help" ]; then
    show_help
    exit 0
fi

# Detect repo and service from input
TARGET_REPO=""
TARGET_SERVICE=""
DOCKER_OPTIONS=""

for arg in "$@"; do
    if is_known_repo "$arg"; then
        TARGET_REPO="$arg"
    elif echo "$arg" | grep -q '^-'; then
        DOCKER_OPTIONS="$DOCKER_OPTIONS $arg"
    else
        TARGET_SERVICE="$arg"
    fi
done

# Determine which repos to operate on
if [ -n "$TARGET_REPO" ]; then
    REPOS_TO_RUN="$TARGET_REPO"
else
    if [ "$COMMAND" = "up" ]; then
        REPOS_TO_RUN="$START_ORDER"
    else
        REPOS_TO_RUN="$STOP_ORDER"
    fi
fi

# Execute each repo
for repo in $REPOS_TO_RUN; do
    run_repo "$COMMAND" "$repo" "$TARGET_SERVICE" $DOCKER_OPTIONS
done

echo "✅ Done!"
