#!/usr/bin/env bash
# =============================================================================
# Notification Platform - Stop All Services
# =============================================================================
# Gracefully stops all running microservices and cleans up PID files.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PID_DIR="$PROJECT_ROOT/.pids"

SERVICE_ORDER=(
    "admin-dashboard-php"
    "admin-dashboard-vite"
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
NC='\033[0m'

echo ""
echo -e "${CYAN}=============================================${NC}"
echo -e "${CYAN}   Notification Platform - Stopping Services ${NC}"
echo -e "${CYAN}=============================================${NC}"
echo ""

if [[ ! -d "$PID_DIR" ]]; then
    echo -e "${YELLOW}No PID directory found. No services appear to be running.${NC}"
    echo ""
    exit 0
fi

STOPPED=0
NOT_RUNNING=0

for SERVICE in "${SERVICE_ORDER[@]}"; do
    # Map pid file names to service entries (match start-all)
    PID_FILE="$PID_DIR/$SERVICE.pid"

    if [[ ! -f "$PID_FILE" ]]; then
        echo -e "${YELLOW}[SKIP]${NC} $SERVICE - No PID file found"
        ((NOT_RUNNING++))
        continue
    fi

    PID=$(cat "$PID_FILE")

    if kill -0 "$PID" 2>/dev/null; then
        # Graceful shutdown (SIGTERM)
        kill "$PID" 2>/dev/null

        # Wait up to 5 seconds for graceful shutdown
        WAIT=0
        while kill -0 "$PID" 2>/dev/null && [[ $WAIT -lt 5 ]]; do
            sleep 1
            ((WAIT++))
        done

        # Force kill if still running
        if kill -0 "$PID" 2>/dev/null; then
            kill -9 "$PID" 2>/dev/null
            echo -e "${YELLOW}[KILL]${NC} $SERVICE force-killed (PID: $PID)"
        else
            echo -e "${GREEN}[OK]${NC}   $SERVICE stopped (PID: $PID)"
        fi
        ((STOPPED++))
    else
        echo -e "${YELLOW}[SKIP]${NC} $SERVICE - Process not running (stale PID: $PID)"
        ((NOT_RUNNING++))
    fi

    rm -f "$PID_FILE"
done

# Clean up log files
rm -f "$PID_DIR"/*.log

echo ""
echo -e "${CYAN}---------------------------------------------${NC}"
echo -e "${GREEN}Stopped: $STOPPED${NC} | ${YELLOW}Not running: $NOT_RUNNING${NC}"
echo -e "${CYAN}---------------------------------------------${NC}"
echo ""
