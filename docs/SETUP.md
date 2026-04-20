# Setup

## Requirements

- macOS
- SwiftBar
- Claude Code
- Python 3
- Optional: LM Studio and its `lms` CLI
- Optional: Codex CLI
- Optional: Google Antigravity

## Install

```bash
git clone https://github.com/YOUR-USER/Agent-Control-TB.git
cd Agent-Control-TB
./install.sh
```

The default install location is:

```bash
~/.agent-control-tb
```

To install elsewhere:

```bash
AGENT_CONTROL_TB_HOME="$HOME/path/to/install" ./install.sh
```

## Shell Integration

Add the line printed by the installer to your shell startup file if you want new
Claude Code sessions to automatically inherit cloud/local mode:

```bash
[[ -f "$HOME/.agent-control-tb/state/claude-env.sh" ]] && source "$HOME/.agent-control-tb/state/claude-env.sh"
```

## First-Time Account Setup

Use the SwiftBar menu:

- `Setup Codex: GPT Pro 1`
- `Setup Codex: GPT Pro 2`
- `Launch Antigravity: Google Pro 1`
- `Launch Antigravity: Google Pro 2`
- `Launch Antigravity: Google Pro 3`

Each action uses an isolated profile slot. Account labels are generic on
purpose; keep emails and account identifiers out of config and logs.
