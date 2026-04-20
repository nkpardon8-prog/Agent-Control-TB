# Architecture

Agent-Control-TB has two control surfaces over the same state:

- SwiftBar for human-visible taskbar control.
- Shell wrappers for Claude Code and other agents.

Runtime state lives under `~/.agent-control-tb` by default:

```text
config/    user-local config
state/     active mode and reviewer state
logs/      run metadata
reports/   reviewer outputs
profiles/  isolated Codex and Antigravity profile data
```

The source repository ships only example config and code. Runtime state is
created by `install.sh` and must not be committed.

## Cloud/Local Claude Mode

Cloud mode clears `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN`.

Local mode sets:

```bash
ANTHROPIC_BASE_URL=<LM Studio base URL>
ANTHROPIC_AUTH_TOKEN=lmstudio
```

Claude Code must be restarted after switching because existing processes do not
inherit new shell or launchd environment values.

## Reviewer Control

The reviewer router chooses one of:

- Codex profile slot
- Antigravity profile slot
- Local LM Studio model

Taskbar selection updates the same state used by:

```bash
~/.agent-control-tb/bin/review-router.sh --provider active --profile active
```
