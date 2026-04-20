#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
actb_init_runtime_dirs

CURRENT=$(cat "$ACTB_STATE_DIR/review_enabled" 2>/dev/null || echo "false")

if [ "$CURRENT" = "true" ]; then
    echo "false" > "$ACTB_STATE_DIR/review_enabled"
    echo "Review disabled."
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Review DISABLED" >> "$ACTB_LOG_DIR/switches.log"
else
    echo "true" > "$ACTB_STATE_DIR/review_enabled"
    echo "Review enabled."
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Review ENABLED" >> "$ACTB_LOG_DIR/switches.log"
fi
actb_refresh_swiftbar
