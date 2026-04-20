# Agent Usage

Claude Code should use Agent-Control-TB when it wants Codex, Antigravity, or a
local LM Studio model to review or act on a task.

## Current State

Claude-readable status:

```bash
cat ~/.agent-control-tb/state/agent-router-status.md
```

Machine-readable status:

```bash
~/.agent-control-tb/bin/review-router.sh --status
```

## Run With The Taskbar-Selected Route

```bash
~/.agent-control-tb/bin/review-router.sh \
  --provider active \
  --profile active \
  --mode agent \
  --prompt-file /path/to/prompt.md
```

## Explicit Overrides

```bash
~/.agent-control-tb/bin/review-router.sh --provider codex --profile gpt-pro-1 --mode agent --prompt-file /path/to/prompt.md
~/.agent-control-tb/bin/review-router.sh --provider antigravity --profile google-pro-1 --mode agent --prompt-file /path/to/prompt.md
~/.agent-control-tb/bin/review-router.sh --provider local --profile local-qwen --mode review --prompt-file /path/to/prompt.md
```

## Taskbar Behavior

SwiftBar updates the same router state used by the CLI. Selecting a profile in
the taskbar changes what `--provider active --profile active` uses.

## Account Setup

Use the SwiftBar setup/launch actions for each account label. Account labels are
generic on purpose; do not place emails, tokens, cookies, or OAuth data in router
config or logs.

Codex profiles use isolated `CODEX_HOME` directories. Antigravity profiles use
isolated `--user-data-dir` directories.

The SwiftBar clear actions move isolated profile directories into
`~/.agent-control-tb/profiles/.cleared/`. They do not touch your default
Codex or Antigravity app profiles.

## Outputs

Router reports are written to:

```bash
~/.agent-control-tb/reports
```

Run metadata is written to:

```bash
~/.agent-control-tb/logs/review-runs.jsonl
```
