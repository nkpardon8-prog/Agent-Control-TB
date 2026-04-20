#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
actb_init_runtime_dirs
PYTHON_BIN="$(actb_python)"

CONFIG="$ACTB_CONFIG_DIR/config.json"
CLAUDE_SETTINGS="$ACTB_CLAUDE_SETTINGS"
ENV_FILE="$ACTB_STATE_DIR/claude-env.sh"

MODE=$(/bin/cat "$ACTB_STATE_DIR/mode" 2>/dev/null || echo "cloud")
REVIEW=$(/bin/cat "$ACTB_STATE_DIR/review_enabled" 2>/dev/null || echo "false")
ROUTER_STATUS=$("$PYTHON_BIN" "$ACTB_HOME/bin/review-router.py" --status 2>/dev/null || true)
MODEL=$("$PYTHON_BIN" -c "import json; print(json.load(open('$CONFIG'))['local_model'])" 2>/dev/null || echo "unknown")
BASE_URL=$("$PYTHON_BIN" -c "import json; print(json.load(open('$CONFIG'))['lmstudio_base_url'])" 2>/dev/null || echo "http://127.0.0.1:1234")
MIN_CONTEXT=$("$PYTHON_BIN" -c "import json; print(json.load(open('$CONFIG')).get('lmstudio_context_length', 81920))" 2>/dev/null || echo "81920")
CLAUDE_MODEL=$("$PYTHON_BIN" -c "import json; print(json.load(open('$CLAUDE_SETTINGS')).get('model', 'unset'))" 2>/dev/null || echo "unknown")

ENV_FILE_MODE="missing"
if [ -f "$ENV_FILE" ]; then
    if /usr/bin/grep -q '^export ANTHROPIC_BASE_URL=' "$ENV_FILE"; then
        ENV_FILE_MODE="local"
    elif /usr/bin/grep -q '^unset ANTHROPIC_BASE_URL' "$ENV_FILE"; then
        ENV_FILE_MODE="cloud"
    else
        ENV_FILE_MODE="unknown"
    fi
fi

CURRENT_URL="${ANTHROPIC_BASE_URL:-}"
CURRENT_TOKEN="${ANTHROPIC_AUTH_TOKEN:-}"
LAUNCHCTL_URL=$(launchctl getenv ANTHROPIC_BASE_URL 2>/dev/null || true)
LAUNCHCTL_TOKEN=$(launchctl getenv ANTHROPIC_AUTH_TOKEN 2>/dev/null || true)
LMSTUDIO_RUNNING=$("$PYTHON_BIN" - "$BASE_URL" <<'PY'
import json
import sys
import urllib.request

base_url = sys.argv[1]
try:
    with urllib.request.urlopen(f"{base_url}/v1/models", timeout=1) as response:
        payload = json.load(response)
except Exception:
    print("not running")
    raise SystemExit(0)

print("running")
PY
)

LOADED_MODELS=""
LOADED_CONTEXT=""
if [ "$LMSTUDIO_RUNNING" = "running" ]; then
    LOADED_MODELS=$("$ACTB_LMS_BIN" ps 2>/dev/null | /usr/bin/awk 'NF >= 6 && $1 != "IDENTIFIER" {printf "%s(context=%s),", $1, $6}' | /usr/bin/sed 's/,$//')
    LOADED_CONTEXT=$("$ACTB_LMS_BIN" ps 2>/dev/null | /usr/bin/awk -v id="$MODEL" 'NF >= 6 && $1 == id {print $6; exit}')
fi

echo "============================================"
echo " Claude Hybrid Control - Status"
echo "============================================"
echo " Control mode:       $MODE"
echo " Env file mode:      $ENV_FILE_MODE"

if [ "$REVIEW" = "true" ]; then
    echo " Review:             enabled"
else
    echo " Review:             disabled"
fi

echo " Local model:        $MODEL"
echo " Local backend URL:  $BASE_URL"
echo " Required context:   $MIN_CONTEXT"
echo " Claude Code model:  $CLAUDE_MODEL"
if [ -n "$ROUTER_STATUS" ]; then
    echo "--------------------------------------------"
    echo "$ROUTER_STATUS"
fi

if [ "$LMSTUDIO_RUNNING" = "running" ]; then
    echo " LM Studio server:   running"
    if [ -n "$LOADED_MODELS" ]; then
        echo " Loaded models:      $LOADED_MODELS"
    else
        echo " Loaded models:      (none)"
    fi
else
    echo " LM Studio server:   not running"
fi

if [ -n "$CURRENT_URL" ]; then
    echo " Current shell URL:  $CURRENT_URL"
else
    echo " Current shell URL:  (unset)"
fi

if [ -n "$CURRENT_TOKEN" ]; then
    echo " Current shell auth: set"
else
    echo " Current shell auth: (unset)"
fi

if [ -n "$LAUNCHCTL_URL" ]; then
    echo " launchctl URL:      $LAUNCHCTL_URL"
else
    echo " launchctl URL:      (unset)"
fi

if [ -n "$LAUNCHCTL_TOKEN" ]; then
    echo " launchctl auth:     set"
else
    echo " launchctl auth:     (unset)"
fi

echo "============================================"

if [ "$MODE" != "$ENV_FILE_MODE" ]; then
    echo " WARNING: mode file and claude-env.sh disagree."
fi

if [ "$MODE" = "cloud" ] && { [ -n "$CURRENT_URL" ] || [ -n "$CURRENT_TOKEN" ]; }; then
    echo " WARNING: this shell still has local Claude env loaded."
    echo " Fix current shell: source $ACTB_STATE_DIR/claude-env.sh"
fi

if [ "$MODE" = "local" ] && [ "$CURRENT_URL" != "$BASE_URL" ]; then
    echo " WARNING: this shell has not picked up local mode."
    echo " Fix current shell: source $ACTB_STATE_DIR/claude-env.sh"
fi

if [ "$MODE" = "local" ] && [ "$CLAUDE_MODEL" != "$MODEL" ]; then
    echo " WARNING: Claude Code model does not match configured local model."
fi

if [ "$MODE" = "local" ] && [ "$LMSTUDIO_RUNNING" != "running" ]; then
    echo " WARNING: local mode is selected, but LM Studio is not reachable."
fi

if [ "$MODE" = "local" ] && [ "$LMSTUDIO_RUNNING" = "running" ] && [ -z "$LOADED_MODELS" ]; then
    echo " WARNING: local mode is selected, but LM Studio has no loaded models."
fi

if [ "$MODE" = "local" ] && [ "$LMSTUDIO_RUNNING" = "running" ] && [ -n "$LOADED_MODELS" ]; then
    case "$LOADED_MODELS" in
        *"$MODEL(context="*) ;;
        *) echo " WARNING: configured local model is not currently loaded in LM Studio." ;;
    esac
fi

if [ "$MODE" = "local" ] && [ -n "$LOADED_CONTEXT" ] && [ "$LOADED_CONTEXT" -lt "$MIN_CONTEXT" ]; then
    echo " WARNING: configured local model context is $LOADED_CONTEXT, below required $MIN_CONTEXT."
fi

echo "============================================"
echo " Note: Claude Code only sees env present when it starts."
echo "============================================"
