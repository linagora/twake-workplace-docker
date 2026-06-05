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
    ["onlyoffice_app"]="${BASE_DIR}/onlyoffice_app"
    ["meet_app"]="${BASE_DIR}/meet_app"
    ["calendar_app"]="${BASE_DIR}/calendar_app"
    ["chat_app"]="${BASE_DIR}/chat_app"
    ["tmail_app"]="${BASE_DIR}/tmail_app"
)

# Order of operations
START_ORDER=("twake_db" "twake_auth" "cozy_stack" "onlyoffice_app" "meet_app" "calendar_app" "chat_app" "tmail_app")
STOP_ORDER=("tmail_app" "chat_app" "calendar_app" "meet_app" "onlyoffice_app" "cozy_stack" "twake_auth" "twake_db")

# ----------------------------
# App selection: friendly flags -> repo
# ----------------------------
# twake_db and twake_auth are shared infrastructure, not user-facing apps, so
# they have no flag. They are pulled in automatically as dependencies (see
# REPO_REQUIRES) of whichever apps are selected.
declare -A APP_FLAGS
APP_FLAGS=(
    ["--mail"]="tmail_app"
    ["--chat"]="chat_app"
    ["--drive"]="cozy_stack"
    ["--meet"]="meet_app"
    ["--calendar"]="calendar_app"
    ["--office"]="onlyoffice_app"
)

# Repo-level dependencies: repos that must also run for a given repo to work.
# Distinct from REPO_DEPS below, which gates startup on individual container
# health. Here we resolve the transitive set of *repos* to bring up.
#   - twake_auth (lemonldap IdP) sits on the openldap/db services in twake_db.
#   - every auth-gated app needs twake_auth, and so transitively twake_db.
#   - onlyoffice_app is not auth-gated; it only needs twake_db's services.
declare -A REPO_REQUIRES
REPO_REQUIRES=(
    ["twake_auth"]="twake_db"
    ["cozy_stack"]="twake_auth"
    ["meet_app"]="twake_auth"
    ["chat_app"]="twake_auth"
    ["calendar_app"]="twake_auth"
    ["tmail_app"]="twake_auth"
    ["onlyoffice_app"]="twake_db"
)

# Dependencies: containers that must be healthy before starting a repo.
# Apps gated on lemonldap-ng:
#   - chat_app: Synapse loads OIDC discovery (.well-known) at boot and refuses
#     to start if the IdP is unreachable.
#   - cozy_stack: confidential client (IDCOZY) with disable_password_authentication=true,
#     so OIDC is the only login path.
#   - meet_app: confidential client (visio) — exchanges code with client_secret server-side.
#   - tmail_app, calendar_app: public clients with lazy introspection, gated as a
#     precaution so the first login is never racing the IdP startup.
# onlyoffice_app gated on its backing services (both live in twake_db, so they
# cannot be expressed as a compose depends_on):
#   - postgres: documentserver stores document/task state there and runs its
#     schema setup at boot.
#   - rabbitmq: documentserver uses AMQP for its converter queues and
#     restart-loops while it is unreachable.
# calendar_app is additionally gated on its backing services (both live in
# twake_db, so they cannot be expressed as a compose depends_on):
#   - mongodb, rabbitmq: the side-service (James) opens both at boot and its
#     /healthcheck probes them, so until they are healthy the aggregate reports
#     UNHEALTHY (503), the container never turns healthy, and the wrapper's
#     health wait fails with "calendar health check failing".
declare -A REPO_DEPS
REPO_DEPS=(
    ["onlyoffice_app"]="postgres rabbitmq"
    ["chat_app"]="lemonldap-ng"
    ["cozy_stack"]="lemonldap-ng"
    ["meet_app"]="lemonldap-ng"
    ["tmail_app"]="lemonldap-ng"
    ["calendar_app"]="lemonldap-ng mongodb rabbitmq"
)

show_help() {
    echo "Usage: $0 <up|down> [repo] [service] [app flags] [docker-compose options]"
    echo
    echo "App flags (start only the selected apps, infra pulled in automatically):"
    echo "  --mail --chat --drive --meet --calendar --office"
    echo "  --full                          All apps (equivalent to listing every flag)"
    echo
    echo "Examples:"
    echo "  $0 up -d                        Start all repos in order"
    echo "  $0 up twake_db                  Start only the twake_db repo"
    echo "  $0 up twake_auth lemonldap      Start only the lemonldap service in twake_auth"
    echo "  $0 up --mail --chat -d          Start mail + chat and their dependencies"
    echo "  $0 up --full -d                 Start every app"
    echo "  $0 down                         Stop all repos in reverse order"
    echo "  $0 down cozy_stack              Stop only cozy_stack"
    echo "  $0 down --chat                  Stop chat only (shared infra left running)"
}

# ----------------------------
# Helper: resolve the transitive set of repos required by the selected ones
# ----------------------------
resolve_deps() {
    local -A seen=()
    local queue=("$@")
    local result=()
    while [[ ${#queue[@]} -gt 0 ]]; do
        local repo="${queue[0]}"
        queue=("${queue[@]:1}")
        if [[ -n "${seen[$repo]}" ]]; then
            continue
        fi
        seen[$repo]=1
        result+=("$repo")
        for dep in ${REPO_REQUIRES[$repo]}; do
            queue+=("$dep")
        done
    done
    echo "${result[@]}"
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

# Detect repo, service and app flags from input
TARGET_REPO=""
TARGET_SERVICE=""
DOCKER_OPTIONS=()
SELECTED_APPS=()
FULL=""

for arg in "$@"; do
    if [[ -n "${APP_FLAGS[$arg]}" ]]; then
        SELECTED_APPS+=("${APP_FLAGS[$arg]}")
    elif [[ "$arg" == "--full" ]]; then
        FULL=1
        for repo in "${APP_FLAGS[@]}"; do
            SELECTED_APPS+=("$repo")
        done
    elif [[ -n "${REPOS[$arg]}" ]]; then
        TARGET_REPO="$arg"
    elif [[ "$arg" =~ ^- ]]; then
        DOCKER_OPTIONS+=("$arg")
    else
        TARGET_SERVICE="$arg"
    fi
done

# App flags select a set of repos; they cannot be combined with a single-repo
# (or repo + service) invocation, which means something different.
if [[ ${#SELECTED_APPS[@]} -gt 0 ]]; then
    if [[ -n "$TARGET_REPO" ]]; then
        echo "❌ Cannot combine app flags with a repo name. Pick one."
        exit 1
    fi
    if [[ -n "$TARGET_SERVICE" ]]; then
        echo "❌ Cannot combine app flags with a service name. Pick one."
        exit 1
    fi
fi

# Determine which repos to operate on
if [[ ${#SELECTED_APPS[@]} -gt 0 ]]; then
    declare -A REQUIRED=()
    if [[ "$COMMAND" == "up" ]]; then
        # Pull in shared infra and any other required repos automatically.
        for repo in $(resolve_deps "${SELECTED_APPS[@]}"); do
            REQUIRED[$repo]=1
        done
        ORDER=("${START_ORDER[@]}")
    else
        # On 'down', tear down only the selected apps so other running apps keep
        # their shared infra. '--full' is the exception: it stops everything.
        if [[ -n "$FULL" ]]; then
            for repo in "${STOP_ORDER[@]}"; do
                REQUIRED[$repo]=1
            done
        else
            for repo in "${SELECTED_APPS[@]}"; do
                REQUIRED[$repo]=1
            done
        fi
        ORDER=("${STOP_ORDER[@]}")
    fi

    REPOS_TO_RUN=()
    for repo in "${ORDER[@]}"; do
        if [[ -n "${REQUIRED[$repo]}" ]]; then
            REPOS_TO_RUN+=("$repo")
        fi
    done
    echo "📦 Selected repos: ${REPOS_TO_RUN[*]}"
elif [[ -n "$TARGET_REPO" ]]; then
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