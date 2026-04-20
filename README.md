# Agent-Control-TB

Agent-Control-TB is a macOS taskbar control plane for Claude Code. It lets you
switch Claude Code between Anthropic cloud mode and local LM Studio mode, and it
gives Claude Code a stable command-line interface for calling reviewer agents
such as Codex, Antigravity, or a local model.

It is built around two surfaces that share the same state:

- SwiftBar menu controls for manual switching, setup, launch, and status.
- Shell wrappers that Claude Code can call during review or agent loops.

## What It Does

- Switch Claude Code between cloud and local LM Studio mode.
- Show current mode, local model, local-review toggle, reviewer route, and last
  reviewer result in the macOS menu bar.
- Route Claude Code review/agent calls to:
  - Codex profile slots
  - Antigravity profile slots
  - Local LM Studio models
- Keep Codex and Antigravity account slots isolated by profile directory.
- Save reviewer outputs and run metadata locally.

## What It Does Not Do

- It does not ship credentials, tokens, cookies, or OAuth data.
- It does not bypass provider limits.
- It does not guarantee exact quota monitoring unless a provider exposes a
  stable status source.
- It does not make existing Claude Code sessions change mode without restart.

## Requirements

- macOS
- [SwiftBar](https://swiftbar.app/)
- Claude Code
- Python 3
- Optional: LM Studio with the `lms` CLI
- Optional: Codex CLI
- Optional: Google Antigravity

## Install

```bash
git clone https://github.com/YOUR-USER/Agent-Control-TB.git
cd Agent-Control-TB
./install.sh
```

The default runtime install is:

```bash
~/.agent-control-tb
```

The installer creates local config, state, logs, reports, and isolated profile
directories. These runtime files are intentionally not part of the source repo.

## Shell Setup

Add this to your shell startup file if you want new Claude Code sessions to pick
up the selected cloud/local mode:

```bash
[[ -f "$HOME/.agent-control-tb/state/claude-env.sh" ]] && source "$HOME/.agent-control-tb/state/claude-env.sh"
```

Claude Code must be restarted after switching cloud/local mode.

## First Run

1. Install and refresh SwiftBar.
2. Open the Agent-Control-TB menu.
3. Confirm cloud mode is active.
4. Configure LM Studio model names in:

   ```bash
   ~/.agent-control-tb/config/config.json
   ```

5. Use the taskbar setup actions for external reviewer accounts:
   - `Setup Codex: GPT Pro 1`
   - `Setup Codex: GPT Pro 2`
   - `Launch Antigravity: Google Pro 1`
   - `Launch Antigravity: Google Pro 2`
   - `Launch Antigravity: Google Pro 3`

## Claude Code Usage

Use the taskbar-selected account/API/local reviewer route:

```bash
~/.agent-control-tb/bin/review-router.sh \
  --provider active \
  --profile active \
  --mode agent \
  --prompt-file /path/to/prompt.md
```

Override explicitly:

```bash
~/.agent-control-tb/bin/review-router.sh --provider codex --profile gpt-pro-1 --mode agent --prompt-file /path/to/prompt.md
~/.agent-control-tb/bin/review-router.sh --provider antigravity --profile google-pro-1 --mode agent --prompt-file /path/to/prompt.md
~/.agent-control-tb/bin/review-router.sh --provider local --profile local-qwen --mode review --prompt-file /path/to/prompt.md
```

Current status:

```bash
~/.agent-control-tb/bin/status.sh
~/.agent-control-tb/bin/review-router.sh --status
cat ~/.agent-control-tb/state/agent-router-status.md
```

## Account Isolation

Codex profile slots use isolated `CODEX_HOME` directories:

```text
~/.agent-control-tb/profiles/codex/gpt-pro-1
~/.agent-control-tb/profiles/codex/gpt-pro-2
```

Antigravity profile slots use isolated `--user-data-dir` directories:

```text
~/.agent-control-tb/profiles/antigravity/google-pro-1
~/.agent-control-tb/profiles/antigravity/google-pro-2
~/.agent-control-tb/profiles/antigravity/google-pro-3
```

Clear actions move profile directories into:

```text
~/.agent-control-tb/profiles/.cleared/
```

They do not touch your default Codex or Antigravity profiles.

## Local Review Toggle

The `Local Review` toggle only gates the LM Studio local review script. Codex
and Antigravity reviewer routes are invoked explicitly by Claude Code through
`review-router.sh`; they are not controlled by the local review toggle.

## Security

Do not commit runtime state. The repository ignores:

- `state/`
- `logs/`
- `reports/`
- `profiles/`
- `backups/`
- `config/config.json`
- `config/router.json`
- common auth, token, cookie, and database files

See [docs/SECURITY.md](docs/SECURITY.md).

## Documentation

- [Setup](docs/SETUP.md)
- [Agent Usage](docs/AGENT_USAGE.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Runbook](docs/RUNBOOK.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Security](docs/SECURITY.md)
- [Uninstall](docs/UNINSTALL.md)

## Uninstall

```bash
./uninstall.sh
```

The uninstaller removes the SwiftBar plugin link and clears launchd Claude env
vars. It leaves runtime files in place so you can inspect or delete them
manually.
