# Security Model

Agent-Control-TB is designed to keep source code separate from runtime secrets.

## What Is Safe To Commit

- Shell and Python source files.
- Example configs under `config/*.example.json`.
- Documentation.
- Installer and uninstaller scripts.

## What Must Never Be Committed

- `profiles/`
- `state/`
- `logs/`
- `reports/`
- `backups/`
- `config/config.json`
- `config/router.json`
- Any `auth.json`, cookie store, token file, SQLite profile database, or OAuth data.

The `.gitignore` blocks these paths by default.

## Account Isolation

Codex profiles use isolated `CODEX_HOME` directories under
`~/.agent-control-tb/profiles/codex/`.

Antigravity profiles use isolated `--user-data-dir` directories under
`~/.agent-control-tb/profiles/antigravity/`.

The clear actions move those isolated folders into
`~/.agent-control-tb/profiles/.cleared/`. They do not touch default application
profiles outside Agent-Control-TB.

## Limits

This project is not intended to bypass provider limits. It gives Claude Code and
SwiftBar explicit profile routing and status visibility. If a profile appears
unavailable or limited, the router should report that state clearly.
