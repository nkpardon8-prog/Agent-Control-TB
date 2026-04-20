#!/bin/bash

ACTB_HOME="${AGENT_CONTROL_TB_HOME:-$HOME/.agent-control-tb}"
ACTB_CONFIG_DIR="$ACTB_HOME/config"
ACTB_STATE_DIR="$ACTB_HOME/state"
ACTB_LOG_DIR="$ACTB_HOME/logs"
ACTB_REPORT_DIR="$ACTB_HOME/reports"
ACTB_PROFILE_DIR="$ACTB_HOME/profiles"
ACTB_LMS_BIN="${LMS_BIN:-$HOME/.lmstudio/bin/lms}"
ACTB_CLAUDE_SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"

actb_python() {
  if command -v python3 >/dev/null 2>&1; then
    command -v python3
  else
    echo "/usr/bin/python3"
  fi
}

actb_refresh_swiftbar() {
  open "swiftbar://refreshallplugins" 2>/dev/null || true
}

actb_init_runtime_dirs() {
  mkdir -p "$ACTB_CONFIG_DIR" "$ACTB_STATE_DIR" "$ACTB_LOG_DIR" "$ACTB_REPORT_DIR" "$ACTB_PROFILE_DIR"
  chmod 700 "$ACTB_PROFILE_DIR" 2>/dev/null || true
}
