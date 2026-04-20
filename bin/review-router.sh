#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
PYTHON_BIN="$(actb_python)"

exec "$PYTHON_BIN" "$ACTB_HOME/bin/review-router.py" "$@"
