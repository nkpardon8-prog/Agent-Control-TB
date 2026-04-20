#!/bin/bash
set -e
# load-model.sh <model-key>
# Loads a model in LM Studio and updates config.json atomically.
# Runs in a terminal (terminal=true from SwiftBar) so the user sees progress.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
actb_init_runtime_dirs
PYTHON_BIN="$(actb_python)"
CONFIG="$ACTB_CONFIG_DIR/config.json"
MODEL="$1"
CONTEXT=$("$PYTHON_BIN" -c "import json; print(json.load(open('$CONFIG')).get('lmstudio_context_length', 81920))" 2>/dev/null || echo "81920")

if [ -z "$MODEL" ]; then
    echo "Usage: load-model.sh <model-key>"
    echo "Example: load-model.sh google/gemma-4-31b"
    exit 1
fi

echo "Loading $MODEL with context length $CONTEXT..."
"$ACTB_LMS_BIN" load "$MODEL" --context-length "$CONTEXT" --identifier "$MODEL" -y

# Atomic config update — write to temp file then mv into place
# Pass values as env vars to avoid shell injection in Python string
TMP=$(mktemp "${CONFIG}.XXXXXX")
MODEL="$MODEL" CONFIG="$CONFIG" TMP="$TMP" "$PYTHON_BIN" -c "
import json, os
p = os.environ['CONFIG']
model = os.environ['MODEL']
c = json.load(open(p))
c['local_model'] = model
c['review_model'] = model
with open(os.environ['TMP'], 'w') as f:
    json.dump(c, f, indent=2)
"
mv "$TMP" "$CONFIG"
echo "Config updated: local_model = $MODEL"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Loaded model: $MODEL" >> "$ACTB_LOG_DIR/switches.log" || true
echo ""
echo "Done. Restart Claude Code if currently in local mode."
