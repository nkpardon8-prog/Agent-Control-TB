#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
actb_init_runtime_dirs
PYTHON_BIN="$(actb_python)"

CLAUDE_SETTINGS="$ACTB_CLAUDE_SETTINGS"
CLOUD_MODEL="${CLAUDE_CLOUD_MODEL:-opus}"

/bin/cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.bak.$(/bin/date '+%Y%m%d-%H%M%S')"
"$PYTHON_BIN" - "$CLAUDE_SETTINGS" "$CLOUD_MODEL" <<'PY'
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
cat > "$ACTB_STATE_DIR/claude-env.sh" << 'EOF'
# Claude Code hybrid mode env — managed by switch-local.sh / switch-cloud.sh
unset ANTHROPIC_BASE_URL
unset ANTHROPIC_AUTH_TOKEN
EOF
echo "cloud" > "$ACTB_STATE_DIR/mode"

launchctl unsetenv ANTHROPIC_BASE_URL
launchctl unsetenv ANTHROPIC_AUTH_TOKEN

echo "Claude Code model: $CLOUD_MODEL"
echo "Switched to Cloud mode. Source $ACTB_STATE_DIR/claude-env.sh or open a new terminal before starting Claude Code."
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Switched to CLOUD (model=$CLOUD_MODEL)" >> "$ACTB_LOG_DIR/switches.log"
actb_refresh_swiftbar
