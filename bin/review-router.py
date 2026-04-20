#!/usr/bin/env python3
"""
Claude Hybrid review/agent router.

This is the shared control point for Claude Code and SwiftBar. It keeps account
labels generic and never logs raw OAuth tokens, cookies, API keys, or emails.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path


BASE_DIR = Path(os.environ.get("AGENT_CONTROL_TB_HOME", str(Path.home() / ".agent-control-tb"))).expanduser()
CONFIG_PATH = BASE_DIR / "config" / "router.json"
LOCAL_CONFIG_PATH = BASE_DIR / "config" / "config.json"
STATE_PATH = BASE_DIR / "state" / "router-state.json"
STATUS_MD_PATH = BASE_DIR / "state" / "agent-router-status.md"
LOG_PATH = BASE_DIR / "logs" / "review-runs.jsonl"
REPORT_DIR = BASE_DIR / "reports"
TRASH_DIR = BASE_DIR / "profiles" / ".cleared"


def now() -> str:
    return dt.datetime.now().replace(microsecond=0).isoformat()


def load_json(path: Path, default: dict) -> dict:
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        return dict(default)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"ERROR: Invalid JSON at {path}: {exc}") from exc


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")


def load_config() -> dict:
    return load_json(CONFIG_PATH, {})


def load_state() -> dict:
    return load_json(
        STATE_PATH,
        {
            "active_provider": "local",
            "active_profile": "local-qwen",
            "routing_mode": "active",
            "last_invoked_provider": None,
            "last_invoked_profile": None,
            "last_result": "not run",
            "last_message": "Router initialized.",
            "last_run_at": None,
            "last_output": None,
        },
    )


def profile_for(config: dict, provider: str, profile: str) -> dict:
    try:
        return config["profiles"][provider][profile]
    except KeyError as exc:
        raise SystemExit(f"ERROR: Unknown route {provider}/{profile}") from exc


def label_for(config: dict, provider: str, profile: str) -> str:
    return profile_for(config, provider, profile).get("label", profile)


def resolve_route(config: dict, state: dict, provider: str, profile: str) -> tuple[str, str]:
    if provider in ("active", ""):
        provider = state.get("active_provider") or "local"
    if profile in ("active", ""):
        profile = state.get("active_profile") or "local-qwen"

    if provider == "auto" or profile == "auto":
        for route in config.get("auto_order", []):
            route_provider = route.get("provider")
            route_profile = route.get("profile")
            if route_provider and route_profile:
                profile_for(config, route_provider, route_profile)
                return route_provider, route_profile
        raise SystemExit("ERROR: auto_order has no valid route")

    profile_for(config, provider, profile)
    return provider, profile


def update_status_md(config: dict, state: dict) -> None:
    active_provider = state.get("active_provider", "local")
    active_profile = state.get("active_profile", "local-qwen")
    try:
        active_label = label_for(config, active_provider, active_profile)
    except SystemExit:
        active_label = active_profile

    lines = [
        "# Claude Reviewer Status",
        "",
        f"- Active route: {active_provider}/{active_profile} ({active_label})",
        f"- Routing mode: {state.get('routing_mode', 'active')}",
        f"- Last invoked: {state.get('last_invoked_provider') or 'none'}/{state.get('last_invoked_profile') or 'none'}",
        f"- Last result: {state.get('last_result', 'not run')}",
        f"- Last message: {state.get('last_message', '')}",
        f"- Last run at: {state.get('last_run_at') or 'never'}",
        f"- Last output: {state.get('last_output') or 'none'}",
        "",
        "Claude Code should call `$AGENT_CONTROL_TB_HOME/bin/review-router.sh` or `~/.agent-control-tb/bin/review-router.sh` for Codex, Antigravity, or local reviewer work.",
        "Use `--provider active --profile active` to follow the taskbar-selected route, or pass an explicit provider/profile override.",
        "",
    ]
    STATUS_MD_PATH.write_text("\n".join(lines))


def persist_state(config: dict, state: dict) -> None:
    write_json(STATE_PATH, state)
    update_status_md(config, state)


def log_run(entry: dict) -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    safe = {
        key: value
        for key, value in entry.items()
        if key not in {"prompt", "token", "auth", "email", "cookie"}
    }
    with LOG_PATH.open("a") as fh:
        fh.write(json.dumps(safe, sort_keys=True) + "\n")


def prompt_text(path: str | None) -> tuple[str, str | None]:
    if not path:
        return "", None
    prompt_path = Path(path).expanduser().resolve()
    text = prompt_path.read_text()
    digest = hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]
    return text, digest


def report_path(provider: str, profile: str) -> Path:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    return REPORT_DIR / f"{stamp}-{provider}-{profile}.md"


def resolve_command(value: str | None, fallback: str) -> str:
    if value:
        expanded = os.path.expandvars(os.path.expanduser(value))
        if "/" in expanded:
            return expanded
        found = shutil.which(expanded)
        if found:
            return found
        return expanded
    found = shutil.which(fallback)
    return found or fallback


def setup_profile(config: dict, provider: str, profile: str) -> int:
    details = profile_for(config, provider, profile)
    if provider == "codex":
        codex_home = Path(details["codex_home"]).expanduser()
        codex_home.mkdir(parents=True, exist_ok=True)
        codex_home.chmod(0o700)
        codex = resolve_command(config.get("commands", {}).get("codex"), "codex")
        print(f"Codex profile directory: {codex_home}")
        print("Starting Codex login for this isolated generic profile.")
        env = os.environ.copy()
        env["CODEX_HOME"] = str(codex_home)
        return subprocess.run([codex, "login"], env=env).returncode
    if provider == "antigravity":
        user_data_dir = Path(details["user_data_dir"]).expanduser()
        user_data_dir.mkdir(parents=True, exist_ok=True)
        user_data_dir.chmod(0o700)
        antigravity = resolve_command(config.get("commands", {}).get("antigravity"), "antigravity")
        profile_name = details.get("profile_name", profile)
        print(f"Launching Antigravity profile: {label_for(config, provider, profile)}")
        cmd = [
            antigravity,
            "--user-data-dir",
            str(user_data_dir),
            "--profile",
            profile_name,
            "--new-window",
            str(Path.cwd()),
        ]
        subprocess.Popen(cmd)
        return 0
    print(f"No setup required for {provider}/{profile}")
    return 0


def clear_profile(config: dict, provider: str, profile: str) -> int:
    details = profile_for(config, provider, profile)
    if provider == "codex":
        target = Path(details["codex_home"]).expanduser()
    elif provider == "antigravity":
        target = Path(details["user_data_dir"]).expanduser()
    elif provider == "local":
        print("Local Qwen has no account profile to clear.")
        return 0
    else:
        raise SystemExit(f"ERROR: Unsupported provider {provider}")

    if not target.exists():
        print(f"No profile data exists for {provider}/{profile}.")
        return 0

    TRASH_DIR.mkdir(parents=True, exist_ok=True)
    TRASH_DIR.chmod(0o700)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    cleared = TRASH_DIR / f"{provider}-{profile}-{stamp}"
    shutil.move(str(target), str(cleared))
    print(f"Cleared {provider}/{profile}. Moved old profile data to:")
    print(cleared)
    return 0


def run_codex(config: dict, profile: str, mode: str, prompt_file: str | None, workdir: Path) -> tuple[int, Path, str]:
    details = profile_for(config, "codex", profile)
    codex_home = Path(details["codex_home"]).expanduser()
    codex_home.mkdir(parents=True, exist_ok=True)
    codex_home.chmod(0o700)
    codex = resolve_command(config.get("commands", {}).get("codex"), "codex")
    output = report_path("codex", profile)

    if not (codex_home / "auth.json").exists():
        message = f"Codex profile {profile} is not logged in. Run setup from SwiftBar first."
        output.write_text(f"# Codex Reviewer Result\n\n{message}\n")
        return 2, output, message

    prompt, _ = prompt_text(prompt_file)
    if not prompt.strip():
        prompt = (
            "Review the current repository state. Focus on bugs, regressions, "
            "security issues, and missing tests. Return concise findings first."
        )

    cmd = [codex, "exec", "--full-auto", "--skip-git-repo-check", prompt]
    env = os.environ.copy()
    env["CODEX_HOME"] = str(codex_home)

    with output.open("w") as fh:
        fh.write(f"# Codex Reviewer Result\n\n- Profile: {profile}\n- Mode: {mode}\n- Started: {now()}\n\n---\n\n")
        fh.flush()
        proc = subprocess.run(cmd, cwd=workdir, env=env, text=True, stdout=fh, stderr=subprocess.STDOUT)

    message = "Codex run complete" if proc.returncode == 0 else f"Codex exited with {proc.returncode}"
    return proc.returncode, output, message


def run_antigravity(config: dict, profile: str, mode: str, prompt_file: str | None, workdir: Path) -> tuple[int, Path, str]:
    details = profile_for(config, "antigravity", profile)
    antigravity = resolve_command(config.get("commands", {}).get("antigravity"), "antigravity")
    user_data_dir = Path(details["user_data_dir"]).expanduser()
    user_data_dir.mkdir(parents=True, exist_ok=True)
    user_data_dir.chmod(0o700)
    output = report_path("antigravity", profile)
    prompt, _ = prompt_text(prompt_file)
    prompt_arg = prompt if prompt.strip() else "Open an agent session for this repository."
    profile_name = details.get("profile_name", profile)

    cmd = [
        antigravity,
        "--user-data-dir",
        str(user_data_dir),
        "--profile",
        profile_name,
        "chat",
        "--mode",
        mode if mode in {"ask", "agent"} else "agent",
        prompt_arg,
    ]

    with output.open("w") as fh:
        fh.write(
            "# Antigravity Reviewer Result\n\n"
            f"- Profile: {profile}\n"
            f"- Mode: {mode}\n"
            f"- Started: {now()}\n\n"
            "Antigravity chat is launched through an isolated user data directory. "
            "If the CLI opens a GUI session without returning final text, treat this as a session handoff.\n\n---\n\n"
        )
        fh.flush()
        try:
            proc = subprocess.run(cmd, cwd=workdir, text=True, stdout=fh, stderr=subprocess.STDOUT, timeout=30)
        except subprocess.TimeoutExpired:
            fh.write("\nAntigravity did not return within 30 seconds. The GUI session was likely launched.\n")
            return 0, output, "Antigravity session launched"

    message = "Antigravity chat command returned" if proc.returncode == 0 else f"Antigravity exited with {proc.returncode}"
    return proc.returncode, output, message


def run_local(config: dict, profile: str, mode: str, prompt_file: str | None, workdir: Path) -> tuple[int, Path, str]:
    local_cfg = load_json(LOCAL_CONFIG_PATH, {})
    base_url = local_cfg.get("lmstudio_base_url", "http://127.0.0.1:1234")
    model = local_cfg.get("review_model") or local_cfg.get("local_model")
    output = report_path("local", profile)
    prompt, _ = prompt_text(prompt_file)
    if not prompt.strip():
        prompt = "Review the current repository and return concise findings first."

    payload = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 8192,
        "temperature": 0.2,
    }
    req = urllib.request.Request(
        f"{base_url}/v1/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "Authorization": "Bearer lmstudio"},
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            result = json.loads(resp.read())
        message = result["choices"][0]["message"]
        content = message.get("content") or message.get("reasoning_content") or "Model returned no content."
        output.write_text(
            f"# Local Reviewer Result\n\n- Profile: {profile}\n- Model: {model}\n- Started: {now()}\n\n---\n\n{content}\n"
        )
        return 0, output, "Local review complete"
    except (urllib.error.URLError, OSError, KeyError, json.JSONDecodeError) as exc:
        output.write_text(f"# Local Reviewer Result\n\nERROR: {exc}\n")
        return 1, output, f"Local review failed: {exc}"


def run_route(config: dict, state: dict, args: argparse.Namespace) -> int:
    provider, profile = resolve_route(config, state, args.provider, args.profile)
    workdir = Path(args.workdir or Path.cwd()).expanduser().resolve()
    prompt_hash = prompt_text(args.prompt_file)[1]

    if provider == "codex":
        code, output, message = run_codex(config, profile, args.mode, args.prompt_file, workdir)
    elif provider == "antigravity":
        code, output, message = run_antigravity(config, profile, args.mode, args.prompt_file, workdir)
    elif provider == "local":
        code, output, message = run_local(config, profile, args.mode, args.prompt_file, workdir)
    else:
        raise SystemExit(f"ERROR: Unsupported provider {provider}")

    result = "success" if code == 0 else "failed"
    state.update(
        {
            "last_invoked_provider": provider,
            "last_invoked_profile": profile,
            "last_result": result,
            "last_message": message,
            "last_run_at": now(),
            "last_output": str(output),
        }
    )
    persist_state(config, state)
    log_run(
        {
            "at": state["last_run_at"],
            "provider": provider,
            "profile": profile,
            "mode": args.mode,
            "workdir": str(workdir),
            "prompt_hash": prompt_hash,
            "result": result,
            "message": message,
            "output": str(output),
        }
    )
    print(message)
    print(f"Output: {output}")
    return code


def print_status(config: dict, state: dict) -> int:
    persist_state(config, state)
    active_provider = state.get("active_provider", "local")
    active_profile = state.get("active_profile", "local-qwen")
    print(f"Active route: {active_provider}/{active_profile} ({label_for(config, active_provider, active_profile)})")
    print(f"Routing mode: {state.get('routing_mode', 'active')}")
    print(f"Last invoked: {state.get('last_invoked_provider') or 'none'}/{state.get('last_invoked_profile') or 'none'}")
    print(f"Last result: {state.get('last_result', 'not run')}")
    print(f"Last message: {state.get('last_message', '')}")
    print(f"Status file: {STATUS_MD_PATH}")
    return 0


def set_active(config: dict, state: dict, provider: str, profile: str, routing_mode: str) -> int:
    provider, profile = resolve_route(config, state, provider, profile)
    state.update(
        {
            "active_provider": provider,
            "active_profile": profile,
            "routing_mode": routing_mode,
            "last_message": f"Active route set to {provider}/{profile}.",
            "last_run_at": now(),
        }
    )
    persist_state(config, state)
    log_run({"at": state["last_run_at"], "event": "set-active", "provider": provider, "profile": profile})
    print(f"Active route set to {provider}/{profile} ({label_for(config, provider, profile)})")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Claude Hybrid reviewer router")
    parser.add_argument("--provider", default="active", choices=["active", "auto", "codex", "antigravity", "local"])
    parser.add_argument("--profile", default="active")
    parser.add_argument("--mode", default="agent", choices=["agent", "ask", "review"])
    parser.add_argument("--prompt-file")
    parser.add_argument("--workdir")
    parser.add_argument("--status", action="store_true")
    parser.add_argument("--set-active", action="store_true")
    parser.add_argument("--setup", action="store_true")
    parser.add_argument("--clear", action="store_true")
    args = parser.parse_args()

    config = load_config()
    state = load_state()

    if args.status:
        return print_status(config, state)

    if args.set_active:
        routing_mode = "auto" if args.provider == "auto" or args.profile == "auto" else "active"
        return set_active(config, state, args.provider, args.profile, routing_mode)

    provider, profile = resolve_route(config, state, args.provider, args.profile)
    if args.setup:
        code = setup_profile(config, provider, profile)
        if code == 0:
            state["last_message"] = f"Setup launched for {provider}/{profile}."
            state["last_run_at"] = now()
            persist_state(config, state)
        return code

    if args.clear:
        code = clear_profile(config, provider, profile)
        if code == 0:
            state["last_message"] = f"Cleared profile {provider}/{profile}."
            state["last_run_at"] = now()
            persist_state(config, state)
            log_run({"at": state["last_run_at"], "event": "clear-profile", "provider": provider, "profile": profile})
        return code

    return run_route(config, state, args)


if __name__ == "__main__":
    raise SystemExit(main())
