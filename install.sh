#!/bin/bash
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${AGENT_CONTROL_TB_HOME:-$HOME/.agent-control-tb}"
SWIFTBAR_DIR="${SWIFTBAR_PLUGIN_DIR:-$HOME/Library/Application Support/SwiftBar/Plugins}"

mkdir -p "$INSTALL_DIR" "$SWIFTBAR_DIR"

rsync -a \
  --exclude '.git' \
  --exclude 'state' \
  --exclude 'logs' \
  --exclude 'reports' \
  --exclude 'profiles' \
  --exclude 'backups' \
  --exclude '__pycache__' \
  --exclude 'config/config.json' \
  --exclude 'config/router.json' \
  "$SRC_DIR/" "$INSTALL_DIR/"

mkdir -p "$INSTALL_DIR/config" "$INSTALL_DIR/state" "$INSTALL_DIR/logs" "$INSTALL_DIR/reports" "$INSTALL_DIR/profiles"
chmod 700 "$INSTALL_DIR/profiles"

if [ ! -f "$INSTALL_DIR/config/config.json" ]; then
  cp "$INSTALL_DIR/config/config.example.json" "$INSTALL_DIR/config/config.json"
fi

if [ ! -f "$INSTALL_DIR/config/router.json" ]; then
  cp "$INSTALL_DIR/config/router.example.json" "$INSTALL_DIR/config/router.json"
fi

if [ ! -f "$INSTALL_DIR/state/mode" ]; then
  echo "cloud" > "$INSTALL_DIR/state/mode"
fi

if [ ! -f "$INSTALL_DIR/state/review_enabled" ]; then
  echo "false" > "$INSTALL_DIR/state/review_enabled"
fi

if [ ! -f "$INSTALL_DIR/state/router-state.json" ]; then
  cat > "$INSTALL_DIR/state/router-state.json" <<'JSON'
{
  "active_provider": "local",
  "active_profile": "local-qwen",
  "routing_mode": "active",
  "last_invoked_provider": null,
  "last_invoked_profile": null,
  "last_result": "not run",
  "last_message": "Router initialized.",
  "last_run_at": null,
  "last_output": null
}
JSON
fi

if [ ! -f "$INSTALL_DIR/state/claude-env.sh" ]; then
  cat > "$INSTALL_DIR/state/claude-env.sh" <<'EOF'
# Claude Code env managed by Agent-Control-TB.
unset ANTHROPIC_BASE_URL
unset ANTHROPIC_AUTH_TOKEN
EOF
fi

chmod +x "$INSTALL_DIR"/bin/*.sh "$INSTALL_DIR"/bin/*.py "$INSTALL_DIR"/swiftbar/*.sh
ln -sf "$INSTALL_DIR/swiftbar/agent-control-tb.10s.sh" "$SWIFTBAR_DIR/agent-control-tb.10s.sh"

python3 "$INSTALL_DIR/bin/review-router.py" --status >/dev/null 2>&1 || true

echo "Agent-Control-TB installed to: $INSTALL_DIR"
echo "SwiftBar plugin linked at: $SWIFTBAR_DIR/agent-control-tb.10s.sh"
echo ""
echo "Optional shell startup line:"
echo "[[ -f \"$INSTALL_DIR/state/claude-env.sh\" ]] && source \"$INSTALL_DIR/state/claude-env.sh\""
echo ""
echo "Next steps:"
echo "1. Open SwiftBar and refresh plugins."
echo "2. Edit $INSTALL_DIR/config/config.json for your LM Studio model names if needed."
echo "3. Use the taskbar setup actions to authenticate isolated Codex and Antigravity profiles."
