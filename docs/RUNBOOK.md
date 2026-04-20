# Runbook

## Show Status

```bash
~/.agent-control-tb/bin/status.sh
~/.agent-control-tb/bin/review-router.sh --status
```

## Switch Claude Mode

```bash
~/.agent-control-tb/bin/switch-cloud.sh
~/.agent-control-tb/bin/switch-local.sh
```

After switching, restart Claude Code from a shell that sourced:

```bash
source ~/.agent-control-tb/state/claude-env.sh
```

## Select Reviewer Route

```bash
~/.agent-control-tb/bin/set-review-route.sh local local-qwen
~/.agent-control-tb/bin/set-review-route.sh codex gpt-pro-1
~/.agent-control-tb/bin/set-review-route.sh antigravity google-pro-1
```

## Run Reviewer From Claude Code

```bash
~/.agent-control-tb/bin/review-router.sh \
  --provider active \
  --profile active \
  --mode agent \
  --prompt-file /path/to/prompt.md
```
