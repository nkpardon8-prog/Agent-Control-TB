#!/bin/bash
# agent-control-tb.10s.sh — SwiftBar plugin for Claude reviewer control
# Refreshes every 10 seconds.

BASE_DIR="${AGENT_CONTROL_TB_HOME:-$HOME/.agent-control-tb}"
LMS_BIN="${LMS_BIN:-$HOME/.lmstudio/bin/lms}"

# Read state files
MODE=$(/bin/cat "$BASE_DIR/state/mode" 2>/dev/null || echo "cloud")
REVIEW=$(/bin/cat "$BASE_DIR/state/review_enabled" 2>/dev/null || echo "false")
ACTIVE_MODEL=$(/usr/bin/python3 -c "import json; print(json.load(open('$BASE_DIR/config/config.json'))['local_model'])" 2>/dev/null || echo "unknown")
BASE_URL=$(/usr/bin/python3 -c "import json; print(json.load(open('$BASE_DIR/config/config.json'))['lmstudio_base_url'])" 2>/dev/null || echo "http://127.0.0.1:1234")
ROUTER_STATUS=$(
/usr/bin/python3 - "$BASE_DIR/state/router-state.json" "$BASE_DIR/config/router.json" 2>/dev/null <<'PY' || echo "local|local-qwen|Local Qwen|not run|Reviewer state unavailable"
import json
import sys

state_path, config_path = sys.argv[1], sys.argv[2]
state = json.load(open(state_path))
config = json.load(open(config_path))
provider = state.get("active_provider", "local")
profile = state.get("active_profile", "local-qwen")
label = config.get("profiles", {}).get(provider, {}).get(profile, {}).get("label", profile)
result = state.get("last_result", "not run")
message = state.get("last_message", "")
print("|".join([provider, profile, label, result, message]))
PY
)
IFS='|' read -r ROUTER_PROVIDER ROUTER_PROFILE ROUTER_LABEL ROUTER_RESULT ROUTER_MESSAGE <<< "$ROUTER_STATUS"

# Check LM Studio server
LMS_UP="false"
if /usr/bin/curl -s --max-time 1 "$BASE_URL/v1/models" > /dev/null 2>&1; then
    LMS_UP="true"
fi

# --- Menu bar title: mode only ---
if [ "$MODE" = "local" ]; then
    if [ "$LMS_UP" = "true" ]; then
        echo "⚡ LOCAL | color=#00AA44 dropdown=true"
    else
        echo "⚡ LOCAL ○ | color=#FF6B35 dropdown=true"
    fi
else
    echo "☁ CLOUD | color=#0099FF dropdown=true"
fi

echo "---"

# --- Status block ---
if [ "$MODE" = "local" ]; then
    echo "MODE: LOCAL ⚡ | color=#00AA44"
else
    echo "MODE: CLOUD ☁ | color=#0099FF"
fi

if [ "$REVIEW" = "true" ]; then
    echo "Review: ON | color=#00AA44"
else
    echo "Review: OFF | color=#888888"
fi

echo "Model: $ACTIVE_MODEL | color=#888888"
echo "Reviewer: $ROUTER_LABEL | color=#888888"
echo "Reviewer result: $ROUTER_RESULT | color=#888888"

if [ "$MODE" = "local" ] && [ "$LMS_UP" = "false" ]; then
    echo "⚠ LM Studio server not running | color=#FF6B35"
fi

echo "---"

# --- Claude mode ---
echo "Claude Mode | color=#888888"
if [ "$MODE" = "local" ]; then
    echo "--✓ Local active | color=#00AA44"
    echo "--Switch to Cloud ☁ | bash=$BASE_DIR/bin/switch-cloud.sh terminal=false refresh=true"
    echo "--Re-apply Local Mode | bash=$BASE_DIR/bin/switch-local.sh terminal=false refresh=true"
else
    echo "--✓ Cloud active | color=#0099FF"
    echo "--Switch to Local ⚡ | bash=$BASE_DIR/bin/switch-local.sh terminal=false refresh=true"
fi

echo "Reviewer | color=#888888"
echo "--Active: $ROUTER_LABEL ($ROUTER_PROVIDER/$ROUTER_PROFILE) | color=#00AA44"
if [ -n "$ROUTER_MESSAGE" ]; then
    echo "--Last: $ROUTER_MESSAGE | color=#888888"
fi
echo "--Use Auto Reviewer | bash=$BASE_DIR/bin/set-review-route.sh param1=auto param2=auto terminal=false refresh=true"
echo "--Use Local: Qwen | bash=$BASE_DIR/bin/set-review-route.sh param1=local param2=local-qwen terminal=false refresh=true"
echo "--Codex | color=#888888"
echo "----Use GPT Pro 1 | bash=$BASE_DIR/bin/set-review-route.sh param1=codex param2=gpt-pro-1 terminal=false refresh=true"
echo "----Use GPT Pro 2 | bash=$BASE_DIR/bin/set-review-route.sh param1=codex param2=gpt-pro-2 terminal=false refresh=true"
echo "--Antigravity | color=#888888"
echo "----Use Google Pro 1 | bash=$BASE_DIR/bin/set-review-route.sh param1=antigravity param2=google-pro-1 terminal=false refresh=true"
echo "----Use Google Pro 2 | bash=$BASE_DIR/bin/set-review-route.sh param1=antigravity param2=google-pro-2 terminal=false refresh=true"
echo "----Use Google Pro 3 | bash=$BASE_DIR/bin/set-review-route.sh param1=antigravity param2=google-pro-3 terminal=false refresh=true"

echo "Local Models | color=#888888"
ALL_LLMS=$("$LMS_BIN" ls 2>/dev/null | grep "variant" | sed 's/ (.*variant.*//' | awk '{$1=$1; print}')
LOADED=$("$LMS_BIN" ps 2>/dev/null | awk 'NF>0 && $1 != "IDENTIFIER" {print $1}')

if [ -z "$ALL_LLMS" ]; then
    echo "--No models installed | color=#888888"
else
    while IFS= read -r model; do
        [ -z "$model" ] && continue
        if echo "$LOADED" | grep -qF "$model"; then
            echo "--● $model | bash=$BASE_DIR/bin/eject-model.sh param1=$model terminal=false refresh=true color=#00AA44"
        else
            echo "--○ $model | bash=$BASE_DIR/bin/load-model.sh param1=$model terminal=true refresh=true color=#888888"
        fi
    done <<< "$ALL_LLMS"
fi

echo "Review Loop | color=#888888"
if [ "$REVIEW" = "true" ]; then
    echo "--Toggle Review Off | bash=$BASE_DIR/bin/toggle-review.sh terminal=false refresh=true"
else
    echo "--Toggle Review On | bash=$BASE_DIR/bin/toggle-review.sh terminal=false refresh=true"
fi
echo "--Open Reviewer Status | bash=/usr/bin/open param1=$BASE_DIR/state/agent-router-status.md terminal=false"
echo "--Open Reviewer Reports | bash=/usr/bin/open param1=$BASE_DIR/reports terminal=false"

echo "Accounts | color=#888888"
echo "--Codex Setup | color=#888888"
echo "----Setup GPT Pro 1 | bash=$BASE_DIR/bin/setup-review-profile.sh param1=codex param2=gpt-pro-1 terminal=true refresh=true"
echo "----Setup GPT Pro 2 | bash=$BASE_DIR/bin/setup-review-profile.sh param1=codex param2=gpt-pro-2 terminal=true refresh=true"
echo "--Antigravity Setup | color=#888888"
echo "----Launch Google Pro 1 | bash=$BASE_DIR/bin/setup-review-profile.sh param1=antigravity param2=google-pro-1 terminal=false refresh=true"
echo "----Launch Google Pro 2 | bash=$BASE_DIR/bin/setup-review-profile.sh param1=antigravity param2=google-pro-2 terminal=false refresh=true"
echo "----Launch Google Pro 3 | bash=$BASE_DIR/bin/setup-review-profile.sh param1=antigravity param2=google-pro-3 terminal=false refresh=true"
echo "--Danger Zone | color=#FF6B35"
echo "----Clear Codex GPT Pro 1 | bash=$BASE_DIR/bin/clear-review-profile.sh param1=codex param2=gpt-pro-1 terminal=true refresh=true"
echo "----Clear Codex GPT Pro 2 | bash=$BASE_DIR/bin/clear-review-profile.sh param1=codex param2=gpt-pro-2 terminal=true refresh=true"
echo "----Clear Antigravity Google Pro 1 | bash=$BASE_DIR/bin/clear-review-profile.sh param1=antigravity param2=google-pro-1 terminal=true refresh=true"
echo "----Clear Antigravity Google Pro 2 | bash=$BASE_DIR/bin/clear-review-profile.sh param1=antigravity param2=google-pro-2 terminal=true refresh=true"
echo "----Clear Antigravity Google Pro 3 | bash=$BASE_DIR/bin/clear-review-profile.sh param1=antigravity param2=google-pro-3 terminal=true refresh=true"

echo "Diagnostics | color=#888888"
echo "--Open LM Studio | bash=$BASE_DIR/bin/open-lmstudio.sh terminal=false"
echo "--Open Logs | bash=/usr/bin/open param1=$BASE_DIR/logs terminal=false"
