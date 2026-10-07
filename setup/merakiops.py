#!/usr/bin/env python3
"""
Telegram monitor bot for a GCP build server. Works in a group/topic or in DM.

Commands (only from ADMIN_ID(s)):
- /status      : uptime, load, RAM, disk, whether a build is running
- /disk        : disk space only
- /ip          : current external IP
- /hours       : active hours (this session, today, this month, total)
- /ccache      : ccache size and hit rate (ccache -s)
- /ccacheclear : wipe the whole ccache (needs /confirm)
- /shutdown    : power off the VM (needs /confirm)
- /reboot      : reboot the VM (needs /confirm)
- /confirm     : confirms the pending action (valid for 30 seconds)

Needs only: python3 + requests   (pip install requests)
"""

import html
import json
import os
import shutil
import subprocess
import threading
import time
from datetime import datetime

import requests

# ---------------- CONFIG (set via environment) ----------------
BOT_TOKEN = os.environ.get("BOT_TOKEN", "PUT_BOT_TOKEN_HERE")
# Your numeric Telegram user ID. Several admins: ADMIN_ID=111,222
ADMIN_IDS = {int(x) for x in os.environ.get("ADMIN_ID", "123456789").split(",") if x.strip()}
# Same values as TG_CHAT / TG_TOPIC in your build script.
# CHAT_ID is the group's ID (negative, like -1001234567890). Empty = DM the first admin.
CHAT_ID = int(os.environ["CHAT_ID"]) if os.environ.get("CHAT_ID") else None
# TOPIC_ID: topic to post boot messages in and to listen on. Empty = whole group / General.
TOPIC_ID = int(os.environ["TOPIC_ID"]) if os.environ.get("TOPIC_ID") else None
DISK_PATH = os.environ.get("DISK_PATH", "/")        # e.g. /mnt/disks/build
CCACHE_DIR = os.environ.get("CCACHE_DIR", "")       # the dir your build user's ccache uses
STATE_FILE = os.environ.get("STATE_FILE", "/var/lib/tgbot/hours.json")
TICK = 60                                           # seconds between active-hours updates
CONFIRM_WINDOW = 30                                 # seconds to confirm dangerous actions
BUILD_PROCS = ["soong_ui", "ninja", "soong_build", "repo", "make"]
# ---------------------------------------------------------------

API = f"https://api.telegram.org/bot{BOT_TOKEN}"
BOOT_TS = time.time() - float(open("/proc/uptime").read().split()[0])
HOME_CHAT = CHAT_ID if CHAT_ID is not None else sorted(ADMIN_IDS)[0]
HOME_THREAD = TOPIC_ID if CHAT_ID is not None else None
BOT_USERNAME = ""
# pending dangerous action, tied to who asked and where
pending = {"action": None, "ts": 0.0, "user": None, "chat": None}
state_lock = threading.Lock()


# ---------- helpers ----------
def send(text, chat=None, thread=None):
    """Send to (chat, thread); defaults to the home group/topic."""
    if chat is None:
        chat, thread = HOME_CHAT, HOME_THREAD
    data = {"chat_id": chat, "text": text, "parse_mode": "HTML",
            "disable_web_page_preview": "true"}
    if thread:
        data["message_thread_id"] = thread
    try:
        requests.post(f"{API}/sendMessage", data=data, timeout=15)
    except requests.RequestException as e:
        print("send failed:", e)


def fmt_dur(sec):
    sec = int(sec)
    h, r = divmod(sec, 3600)
    m, _ = divmod(r, 60)
    return f"{h}h {m}m"


def external_ip():
    """GCP metadata server first, public lookup as fallback."""
    try:
        r = requests.get(
            "http://metadata.google.internal/computeMetadata/v1/instance/"
            "network-interfaces/0/access-configs/0/external-ip",
            headers={"Metadata-Flavor": "Google"}, timeout=5)
        if r.ok and r.text.strip():
            return r.text.strip()
    except requests.RequestException:
        pass
    try:
        return requests.get("https://api.ipify.org", timeout=5).text.strip()
    except requests.RequestException:
        return "unknown"


def disk_info():
    t, u, f = shutil.disk_usage(DISK_PATH)
    g = 1024 ** 3
    return f"{DISK_PATH}: {f/g:.1f} GB free of {t/g:.1f} GB ({u/t*100:.0f}% used)"


def ram_info():
    mem = {}
    for line in open("/proc/meminfo"):
        k, v = line.split(":")
        mem[k] = int(v.split()[0]) * 1024
    total, avail = mem["MemTotal"], mem["MemAvailable"]
    g = 1024 ** 3
    return f"{(total-avail)/g:.1f} / {total/g:.1f} GB used"


def build_running():
    for p in BUILD_PROCS:
        if subprocess.run(["pgrep", "-x", p], capture_output=True).returncode == 0:
            return p
    return None


# ---------- ccache ----------
def ccache_run(*args):
    env = os.environ.copy()
    if CCACHE_DIR:
        env["CCACHE_DIR"] = CCACHE_DIR
    try:
        r = subprocess.run(["ccache", *args], capture_output=True, text=True,
                           timeout=60, env=env)
        return (r.stdout + r.stderr).strip() or "(no output)"
    except FileNotFoundError:
        return "ccache is not installed (sudo apt install ccache)"
    except subprocess.TimeoutExpired:
        return "ccache timed out"


def ccache_report():
    out = ccache_run("-s")
    return "<b>ccache</b>\n<pre>" + html.escape(out[:3500]) + "</pre>"


# ---------- active hours tracking ----------
def load_state():
    try:
        with open(STATE_FILE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {"days": {}}


def save_state(state):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f)
    os.replace(tmp, STATE_FILE)


def tracker():
    last = time.time()
    while True:
        time.sleep(TICK)
        now = time.time()
        day = datetime.now().strftime("%Y-%m-%d")
        with state_lock:
            st = load_state()
            st["days"][day] = st["days"].get(day, 0) + (now - last)
            save_state(st)
        last = now


def hours_report():
    with state_lock:
        days = load_state()["days"]
    today = datetime.now().strftime("%Y-%m-%d")
    month = today[:7]
    return (
        f"<b>Active hours</b>\n"
        f"This session: {fmt_dur(time.time() - BOOT_TS)}\n"
        f"Today: {fmt_dur(days.get(today, 0))}\n"
        f"This month: {fmt_dur(sum(v for k, v in days.items() if k.startswith(month)))}\n"
        f"Total tracked: {fmt_dur(sum(days.values()))}"
    )


# ---------- commands ----------
def status_report():
    load1, load5, load15 = os.getloadavg()
    b = build_running()
    return (
        f"<b>Server is ACTIVE</b>\n"
        f"IP: <code>{external_ip()}</code>\n"
        f"Uptime: {fmt_dur(time.time() - BOOT_TS)}\n"
        f"CPU load: {load1:.2f} / {load5:.2f} / {load15:.2f} ({os.cpu_count()} vCPU)\n"
        f"RAM: {ram_info()}\n"
        f"Disk: {disk_info()}\n"
        f"Build: {'running (' + b + ')' if b else 'no build process found'}"
    )


def ask_confirm(action, label, user, chat, thread):
    pending.update(action=action, ts=time.time(), user=user, chat=chat)
    b = build_running()
    warn = f"\nA build looks active ({b})!" if b else ""
    send(f"{label}\nSend /confirm within {CONFIRM_WINDOW}s to proceed.{warn}", chat, thread)


def run_pending(chat, thread):
    action = pending["action"]
    pending["action"] = None
    if action == "shutdown":
        send("Shutting down now. Start it again from the GCP console.", chat, thread)
        time.sleep(2)
        subprocess.run(["shutdown", "-h", "now"])
    elif action == "reboot":
        send("Rebooting. You will get a message with the new IP when it is back.", chat, thread)
        time.sleep(2)
        subprocess.run(["shutdown", "-r", "now"])
    elif action == "ccacheclear":
        send("Clearing ccache...", chat, thread)
        ccache_run("-C")
        send(ccache_report(), chat, thread)


def handle(cmd, user, chat, thread):
    cmd = cmd.lower()
    r = (chat, thread)

    if cmd in ("/start", "/help"):
        send("/status /disk /ip /hours /ccache /ccacheclear /shutdown /reboot", *r)
    elif cmd == "/status":
        send(status_report(), *r)
    elif cmd == "/disk":
        send(disk_info(), *r)
    elif cmd == "/ip":
        send(f"<code>{external_ip()}</code>", *r)
    elif cmd == "/hours":
        send(hours_report(), *r)
    elif cmd == "/ccache":
        send(ccache_report(), *r)
    elif cmd == "/ccacheclear":
        ask_confirm("ccacheclear", "This wipes the ENTIRE ccache. Next build will be slow.", user, chat, thread)
    elif cmd == "/shutdown":
        ask_confirm("shutdown", "Power off the server?", user, chat, thread)
    elif cmd == "/reboot":
        ask_confirm("reboot", "Reboot the server?", user, chat, thread)
    elif cmd == "/confirm":
        ok = (pending["action"] and pending["user"] == user and pending["chat"] == chat
              and time.time() - pending["ts"] <= CONFIRM_WINDOW)
        if ok:
            run_pending(chat, thread)
        else:
            pending["action"] = None
            send("Nothing pending (or it expired). Send the command again.", *r)


def allowed_here(msg, chat, thread):
    """Admin DM, or the configured group (and topic, if TOPIC_ID is set)."""
    user = msg.get("from", {}).get("id")
    if user not in ADMIN_IDS:
        return False
    if msg.get("chat", {}).get("type") == "private":
        return True
    if CHAT_ID is None or chat != CHAT_ID:
        return False
    return TOPIC_ID is None or thread == TOPIC_ID


def main():
    global BOT_USERNAME
    try:
        BOT_USERNAME = requests.get(f"{API}/getMe", timeout=15).json()["result"]["username"].lower()
    except (requests.RequestException, KeyError, ValueError):
        pass

    send(f"<b>Server booted</b>\nIP: <code>{external_ip()}</code>\n{disk_info()}")
    threading.Thread(target=tracker, daemon=True).start()

    offset = None
    while True:
        try:
            r = requests.get(f"{API}/getUpdates",
                             params={"timeout": 30, "offset": offset,
                                     "allowed_updates": json.dumps(["message"])},
                             timeout=40).json()
        except (requests.RequestException, ValueError):
            time.sleep(5)
            continue
        for u in r.get("result", []):
            offset = u["update_id"] + 1
            msg = u.get("message") or {}
            chat = msg.get("chat", {}).get("id")
            # thread id only counts when the group really uses topics
            thread = msg.get("message_thread_id") if msg.get("is_topic_message") else None
            if not allowed_here(msg, chat, thread):
                continue  # ignore everyone else, silently
            text = msg.get("text", "")
            if not text.startswith("/"):
                continue
            cmd, _, target = text.split()[0].partition("@")
            if target and BOT_USERNAME and target.lower() != BOT_USERNAME:
                continue  # command meant for another bot in the group
            handle(cmd, msg["from"]["id"], chat, thread)


if __name__ == "__main__":
    main()
