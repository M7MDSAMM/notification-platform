#!/usr/bin/env bash
# =============================================================================
# Notification Platform - Start All Services
# =============================================================================
# Starts all microservices using php artisan serve on their configured ports.
# Each service runs as a background process with its PID stored for management.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SERVICES_DIR="$PROJECT_ROOT/services"
PID_DIR="$PROJECT_ROOT/.pids"

# Service definitions: name → port (standard Laravel serve)
declare -A SERVICES=(
    ["admin-dashboard"]=8000
    ["user-service"]=8001
    ["notification-service"]=8002
    ["messaging-service"]=8003
    ["template-service"]=8004
)

# Ordered list for consistent startup sequence
SERVICE_ORDER=(
    "admin-dashboard"
    "user-service"
    "notification-service"
    "messaging-service"
    "template-service"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}=============================================${NC}"
echo -e "${CYAN}   Notification Platform - Starting Services ${NC}"
echo -e "${CYAN}=============================================${NC}"
echo ""

# Create PID directory
mkdir -p "$PID_DIR"

# Check if any services are already running
ALREADY_RUNNING=false
for SERVICE in "${SERVICE_ORDER[@]}"; do
    PID_FILE="$PID_DIR/$SERVICE.pid"
    if [[ -f "$PID_FILE" ]]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo -e "${YELLOW}[SKIP]${NC} $SERVICE is already running (PID: $PID)"
            ALREADY_RUNNING=true
        else
            rm -f "$PID_FILE"
        fi
    fi
done

if [[ "$ALREADY_RUNNING" == true ]]; then
    echo ""
    echo -e "${YELLOW}Some services are already running. Stop them first with stop-all.sh or let this script start the missing ones only.${NC}"
    echo ""
fi

# Start each service
STARTED=0
FAILED=0

for SERVICE in "${SERVICE_ORDER[@]}"; do
    PORT=${SERVICES[$SERVICE]}
    SERVICE_PATH="$SERVICES_DIR/$SERVICE"
    PID_FILE="$PID_DIR/$SERVICE.pid"
    LOG_FILE="$PID_DIR/$SERVICE.log"

    # Skip if already running
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        continue
    fi

    # Verify service directory exists
    if [[ ! -d "$SERVICE_PATH" ]]; then
        echo -e "${RED}[FAIL]${NC} $SERVICE - Directory not found: $SERVICE_PATH"
        ((FAILED++))
        continue
    fi

    # Verify artisan exists
    if [[ ! -f "$SERVICE_PATH/artisan" ]]; then
        echo -e "${RED}[FAIL]${NC} $SERVICE - Not a Laravel project (artisan not found)"
        FAILED=$((FAILED + 1))
        continue
    fi

    # Start the service (run in its directory) and capture PID
    PID=$( (cd "$SERVICE_PATH" && php artisan serve --host=127.0.0.1 --port="$PORT" > "$LOG_FILE" 2>&1 & echo $!) )
    echo "$PID" > "$PID_FILE"

    # Brief pause to check if process started successfully
    sleep 0.5
    if kill -0 "$PID" 2>/dev/null; then
        echo -e "${GREEN}[OK]${NC}   $SERVICE started on port ${CYAN}$PORT${NC} (PID: $PID)"
        STARTED=$((STARTED + 1))
    else
        echo -e "${RED}[FAIL]${NC} $SERVICE failed to start on port $PORT"
        rm -f "$PID_FILE"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo -e "${CYAN}---------------------------------------------${NC}"
echo -e "${GREEN}Started: $STARTED${NC} | ${RED}Failed: $FAILED${NC}"
echo -e "${CYAN}---------------------------------------------${NC}"
echo ""

if [[ $STARTED -gt 0 ]]; then
    echo -e "Service URLs:"
    for SERVICE in "${SERVICE_ORDER[@]}"; do
        ENTRY=${SERVICES[$SERVICE]}
        PORT="${ENTRY%%|*}"
        PID_FILE="$PID_DIR/$SERVICE.pid"
        if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo -e "  ${CYAN}$SERVICE${NC} → http://127.0.0.1:$PORT"
        fi
    done
    echo ""
fi

echo -e "Logs directory: $PID_DIR/"
echo -e "Stop all:       ${YELLOW}./scripts/stop-all.sh${NC}"
echo ""
