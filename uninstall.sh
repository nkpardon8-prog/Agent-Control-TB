#!/bin/bash
set -euo pipefail

INSTALL_DIR="${AGENT_CONTROL_TB_HOME:-$HOME/.agent-control-tb}"
SWIFTBAR_DIR="${SWIFTBAR_PLUGIN_DIR:-$HOME/Library/Application Support/SwiftBar/Plugins}"

launchctl unsetenv ANTHROPIC_BASE_URL 2>/dev/null || true
launchctl unsetenv ANTHROPIC_AUTH_TOKEN 2>/dev/null || true
rm -f "$SWIFTBAR_DIR/agent-control-tb.10s.sh"

echo "Removed SwiftBar plugin and cleared launchctl Claude env vars."
echo "Runtime files are still at: $INSTALL_DIR"
echo "Delete that directory manually if you want to remove configs, logs, reports, and isolated profile auth."
