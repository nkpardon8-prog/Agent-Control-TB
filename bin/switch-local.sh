#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
actb_init_runtime_dirs
PYTHON_BIN="$(actb_python)"

CONFIG="$ACTB_CONFIG_DIR/config.json"
CLAUDE_SETTINGS="$ACTB_CLAUDE_SETTINGS"

read -r URL PREFERRED_MODEL MIN_CONTEXT < <("$PYTHON_BIN" - "$CONFIG" <<'PY'
import json
import sys
import urllib.request

config_path = sys.argv[1]

try:
    with open(config_path) as f:
        config = json.load(f)
except Exception as exc:
    print(f"ERROR: Could not read valid JSON from {config_path}: {exc}", file=sys.stderr)
    raise SystemExit(1)

base_url = config.get("lmstudio_base_url") or "http://127.0.0.1:1234"
preferred = config.get("local_model")
min_context = int(config.get("lmstudio_context_length", 81920))

try:
    with urllib.request.urlopen(f"{base_url}/v1/models", timeout=2) as response:
        payload = json.load(response)
except Exception as exc:
    print(f"ERROR: LM Studio server not reachable at {base_url}: {exc}", file=sys.stderr)
    print("Start it: open LM Studio -> Developer tab -> toggle 'Start server' ON", file=sys.stderr)
    raise SystemExit(1)

print(base_url, preferred or "", min_context)
PY
)

if [ -z "$URL" ] || [ -z "$MIN_CONTEXT" ]; then
    echo "ERROR: Could not select a local model."
    exit 1
fi

LOADED_MODELS=$("$ACTB_LMS_BIN" ps 2>/dev/null | /usr/bin/awk 'NF >= 6 && $1 != "IDENTIFIER" {print $1 "|" $6}')

if [ -z "$LOADED_MODELS" ]; then
    echo "ERROR: LM Studio is running at $URL, but no models are loaded."
    echo "Load a model from the taskbar model list, then switch to Local again."
    exit 1
fi

MODEL=""
LOADED_CONTEXT=""

if [ -n "$PREFERRED_MODEL" ]; then
    MATCH=$(echo "$LOADED_MODELS" | /usr/bin/awk -F'|' -v id="$PREFERRED_MODEL" '$1 == id {print; exit}')
    if [ -n "$MATCH" ]; then
        MODEL="${MATCH%%|*}"
        LOADED_CONTEXT="${MATCH#*|}"
    fi
fi

if [ -z "$MODEL" ]; then
    FIRST=$(echo "$LOADED_MODELS" | /usr/bin/head -n 1)
    MODEL="${FIRST%%|*}"
    LOADED_CONTEXT="${FIRST#*|}"
fi

if [ -z "$MODEL" ] || [ -z "$LOADED_CONTEXT" ]; then
    echo "ERROR: Could not parse loaded LM Studio models from 'lms ps'."
    exit 1
fi

if [ "$LOADED_CONTEXT" -lt "$MIN_CONTEXT" ]; then
    echo "ERROR: $MODEL is loaded with context $LOADED_CONTEXT, but Claude Code local mode requires at least $MIN_CONTEXT."
    echo "Reload it from the taskbar model list or run:"
    echo "  \"$ACTB_LMS_BIN\" unload \"$MODEL\""
    echo "  \"$ACTB_LMS_BIN\" load \"$MODEL\" --context-length \"$MIN_CONTEXT\" --identifier \"$MODEL\" -y"
    exit 1
fi

"$PYTHON_BIN" - "$CONFIG" "$MODEL" <<'PY'
import json
import sys

config_path, model = sys.argv[1], sys.argv[2]
with open(config_path) as f:
    config = json.load(f)

config["local_model"] = model
config["review_model"] = model

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PY

/bin/cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.bak.$(/bin/date '+%Y%m%d-%H%M%S')"
"$PYTHON_BIN" - "$CLAUDE_SETTINGS" "$MODEL" <<'PY'
import json
import sys

settings_path, model = sys.argv[1], sys.argv[2]
with open(settings_path) as f:
    settings = json.load(f)

settings["model"] = model

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PY

# Write env file so new terminals/shells pick up the vars automatically
cat > "$ACTB_STATE_DIR/claude-env.sh" << EOF
# Claude Code hybrid mode env — managed by switch-local.sh / switch-cloud.sh
export ANTHROPIC_BASE_URL="$URL"
export ANTHROPIC_AUTH_TOKEN="lmstudio"
EOF
echo "local" > "$ACTB_STATE_DIR/mode"

launchctl setenv ANTHROPIC_BASE_URL "$URL"
launchctl setenv ANTHROPIC_AUTH_TOKEN "lmstudio"

echo "LM Studio server: running at $URL"
echo "Claude Code model: $MODEL"
echo "LM Studio context: $LOADED_CONTEXT"
echo "Switched to Local mode. Source $ACTB_STATE_DIR/claude-env.sh or open a new terminal before starting Claude Code."
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Switched to LOCAL ($URL, model=$MODEL)" >> "$ACTB_LOG_DIR/switches.log"
actb_refresh_swiftbar
