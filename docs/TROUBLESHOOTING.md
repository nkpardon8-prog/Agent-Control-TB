# Troubleshooting

## SwiftBar Does Not Show The Menu

Run:

```bash
bash -n ~/.agent-control-tb/swiftbar/agent-control-tb.10s.sh
~/.agent-control-tb/swiftbar/agent-control-tb.10s.sh
```

Then refresh SwiftBar plugins.

## Claude Code Did Not Switch Cloud/Local Mode

Claude Code reads environment variables at process start. After switching mode,
start a new Claude Code session from a shell that has sourced:

```bash
source ~/.agent-control-tb/state/claude-env.sh
```

## LM Studio Is Reachable But No Model Is Loaded

Open LM Studio, start the local server, and load a model with enough context.
The taskbar model list can load models through the LM Studio `lms` CLI.

## Codex Profile Is Not Logged In

Use SwiftBar:

```text
Setup Codex: GPT Pro 1
```

That runs `codex login` with an isolated `CODEX_HOME`.

## Antigravity Opens A Window Instead Of Returning Text

That is expected on some Antigravity CLI flows. Treat the run as a GUI session
handoff unless the CLI returns final text.
