#!/bin/bash
# eject-model.sh <identifier>   — eject a specific model
# eject-model.sh --all          — eject all loaded models
# No args prints usage (prevents accidental mass eject)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
actb_init_runtime_dirs
MODEL="$1"

if [ -z "$MODEL" ]; then
    echo "Usage: eject-model.sh <identifier>  — eject a specific model"
    echo "       eject-model.sh --all          — eject all loaded models"
    exit 1
fi

if [ "$MODEL" = "--all" ]; then
    "$ACTB_LMS_BIN" unload --all
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ejected all models" >> "$ACTB_LOG_DIR/switches.log" || true
    echo "All models ejected."
else
    "$ACTB_LMS_BIN" unload "$MODEL"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ejected model: $MODEL" >> "$ACTB_LOG_DIR/switches.log" || true
    echo "Ejected: $MODEL"
fi
