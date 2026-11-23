"""Discord <-> Maestro bridge (Phase 4).

An allowed Discord user chats with a Maestro agent in a channel. Messages are
forwarded to `maestro-cli send <agent> "<message>"` and the reply is posted back.

Safety: allowlists are mandatory — no token, no run; no allowed users/channels,
no run. Use this only with agents working inside an authorized scope.
"""

from __future__ import annotations

import asyncio
import fnmatch
import os
import re
import shlex
import shutil
import sqlite3
import subprocess
import sys
from pathlib import Path

import discord


def _find_maestro_cli() -> str:
    env = os.environ.get("MAESTRO_CLI")
    if env:
        return env
    found = shutil.which("maestro-cli")
    if found:
        return found
    home = Path.home()
    candidates = [
        home / ".local/bin/maestro-cli",
        Path("/usr/local/bin/maestro-cli"),
        home / "Applications/Maestro.app/Contents/Resources/maestro-cli",
    ]
    local = os.environ.get("LOCALAPPDATA")
    if local:
        candidates.append(Path(local) / "Programs/Maestro/resources/maestro-cli.exe")
    for c in candidates:
        if c.exists():
            return str(c)
    return "maestro-cli"


TOKEN = os.environ.get("DISCORD_BOT_TOKEN", "")
CLI = _find_maestro_cli()
AGENT = os.environ.get("MAESTRO_AGENT", "hackbot-lead")
ALLOWED_USERS = {
    u.strip() for u in os.environ.get("ALLOWED_USER_IDS", "").split(",") if u.strip()
}
ALLOWED_CHANNELS = {
    c.strip() for c in os.environ.get("ALLOWED_CHANNEL_IDS", "").split(",") if c.strip()
}
TIMEOUT = int(os.environ.get("AGENT_TIMEOUT", "300"))
HARNESS_DB = Path(
    os.environ.get(
        "HARNESS_DB",
        str(Path(__file__).resolve().parent.parent / "harness" / "hackbots.db"),
    )
)
HUNT_WORDS = re.compile(
    r"\b(hunt|scan|recon|fingerprint|enumerate|attack|exploit|test|probe|crawl)\b",
    re.I,
)
HOST_RE = re.compile(r"(?:https?://)?([a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+)", re.I)


def _host(value: str) -> str:
    return value.strip().lower().split("://")[-1].split("/")[0].split(":")[0]


def _matches(patterns: str, host: str) -> bool:
    for p in re.split(r"[,;\n\r ]+", patterns or ""):
        p = p.strip()
        if not p:
            continue
        if fnmatch.fnmatch(host, p) or fnmatch.fnmatch(host, p.lstrip("*.")):
            return True
        if p.startswith("*.") and host.endswith(p[1:]):
            return True
        if p in host or host.endswith("." + p):
            return True
    return False


def scope_gate(content: str) -> str | None:
    """Refuse hunt-like messages whose hosts are not in a recorded authorized scope."""
    if not HUNT_WORDS.search(content):
        return None
    hosts = {_host(m) for m in HOST_RE.findall(content)}
    hosts = {h for h in hosts if "." in h and not h.endswith((".md", ".py", ".js", ".txt", ".sh"))}
    if not hosts:
        return None
    if not HARNESS_DB.exists():
        return "🚫 Blocked: harness DB not found; no authorized scope can be verified."
    con = sqlite3.connect(HARNESS_DB)
    con.row_factory = sqlite3.Row
    try:
        targets = [dict(r) for r in con.execute("SELECT * FROM targets").fetchall()]
    finally:
        con.close()
    if not targets:
        return (
            "🚫 Blocked: no authorized targets are recorded in the harness. "
            "Add the target with written authorization in the dashboard Targets page first."
        )
    for h in sorted(hosts):
        allowed = any(
            _matches(t["in_scope"], h) and not _matches(t["out_of_scope"], h)
            for t in targets
        )
        if not allowed:
            return (
                f"🚫 Blocked: `{h}` is not inside any recorded authorized scope "
                "(or is explicitly out of scope). Record it in the dashboard with "
                "written authorization before hunting."
            )
    return None

intents = discord.Intents.default()
intents.message_content = True
client = discord.Client(intents=intents)


def run_cli(args: list[str]) -> str:
    try:
        result = subprocess.run(
            [CLI, *args],
            capture_output=True,
            text=True,
            timeout=TIMEOUT,
        )
        output = (result.stdout or "").strip()
        if result.returncode != 0:
            output = (output + "\n" + (result.stderr or "")).strip()
        return output or f"(no output, exit {result.returncode})"
    except subprocess.TimeoutExpired:
        return f"ERROR: agent timed out after {TIMEOUT}s"
    except Exception as exc:
        return f"ERROR: {exc}"


def allowed(message: discord.Message) -> bool:
    if message.author.bot:
        return False
    if ALLOWED_USERS and str(message.author.id) not in ALLOWED_USERS:
        return False
    if ALLOWED_CHANNELS and str(message.channel.id) not in ALLOWED_CHANNELS:
        return False
    return True


@client.event
async def on_ready() -> None:
    print(f"Logged in as {client.user} (agent={AGENT})", flush=True)


@client.event
async def on_message(message: discord.Message) -> None:
    if not allowed(message):
        return
    content = message.content.strip()
    if not content:
        return

    if content.startswith("!help"):
        await message.reply(
            "Send any message to talk to the Maestro agent.\n"
            "`!status` — Auto Run status\n"
            "`!agent <name>` — show current agent\n"
            "Only allowlisted users/channels are served."
        )
        return
    if content.startswith("!status"):
        out = await asyncio.to_thread(
            run_cli, ["auto-run-status", "--agent", AGENT]
        )
        await message.reply(f"```{out[:1900]}```")
        return
    if content.startswith("!agent"):
        await message.reply(f"Current agent: `{AGENT}`")
        return

    blocked = scope_gate(content)
    if blocked:
        await message.reply(blocked)
        return

    await message.channel.send("⏳ Working…")
    out = await asyncio.to_thread(run_cli, ["send", AGENT, content])
    # Trim to Discord's 2000-char limit, keep the tail if too long.
    if len(out) > 1900:
        out = "…(truncated)\n" + out[-1850:]
    await message.reply(out)


def check() -> None:
    print("token:", "set" if TOKEN else "MISSING")
    print("maestro cli:", CLI, "exists:", Path(CLI).exists())
    print("agent:", AGENT)
    print("allowed users:", sorted(ALLOWED_USERS) or "NONE (will deny all)")
    print("allowed channels:", sorted(ALLOWED_CHANNELS) or "NONE (any channel)")
    ok = bool(TOKEN) and Path(CLI).exists() and bool(ALLOWED_USERS)
    print("READY" if ok else "NOT READY — see missing items above")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    if "--check" in sys.argv:
        check()
    else:
        if not TOKEN:
            sys.exit("ERROR: set DISCORD_BOT_TOKEN")
        if not Path(CLI).exists():
            sys.exit(f"ERROR: maestro-cli not found: {CLI}")
        client.run(TOKEN)
