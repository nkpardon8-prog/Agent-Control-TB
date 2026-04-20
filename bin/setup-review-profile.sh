#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
PYTHON_BIN="$(actb_python)"

PROVIDER="${1:-active}"
PROFILE="${2:-active}"

"$PYTHON_BIN" "$ACTB_HOME/bin/review-router.py" \
  --provider "$PROVIDER" \
  --profile "$PROFILE" \
  --setup

actb_refresh_swiftbar
