#!/usr/bin/env python3
"""Reinstall, after a self-reflash, the apps that were installed before it.

Run once by reachy-restore-apps.service on the new OS's first boot. Reads the
app names the upgrade recorded, waits for the daemon, and installs each one
the new image does not already ship through the daemon's app store API. The
list file is renamed when done, which stops the service from running again.
"""

import json
import time
import urllib.request
from pathlib import Path

API = "http://localhost:8000/api"
LIST = Path.home() / ".config/reachy_mini/restore-apps.json"


def call(method: str, path: str, body: object = None, timeout: float = 30) -> object:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        API + path, data=data, method=method, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.load(resp)


def wait_for(path: str, deadline_s: float) -> object:
    end = time.monotonic() + deadline_s
    while True:
        try:
            return call("GET", path)
        except Exception:
            if time.monotonic() > end:
                raise
            time.sleep(10)


def main() -> None:
    wanted = json.loads(LIST.read_text())
    wait_for("/daemon/status", 600)
    installed = {a["name"] for a in call("GET", "/apps/list-available/installed")}
    missing = [n for n in wanted if n not in installed]
    print(f"to reinstall: {missing} (already there: {sorted(installed & set(wanted))})")

    # The app store needs the internet, which can take a while after boot.
    store = {a["name"]: a for a in wait_for("/apps/list-available/hf_space", 1800)}
    failed = []
    for name in missing:
        app = store.get(name)
        if app is None:
            print(f"{name}: not in the app store (private or local app), skipped")
            failed.append(name)
            continue
        job = call("POST", "/apps/install", app)["job_id"]
        while True:
            time.sleep(5)
            status = call("GET", f"/apps/job-status/{job}")
            if status["status"] not in ("pending", "in_progress"):
                break
        print(f"{name}: {status['status']}")
        if status["status"] != "done":
            failed.append(name)

    LIST.rename(LIST.with_suffix(".done"))
    if failed:
        print(f"not reinstalled: {failed}")


if __name__ == "__main__":
    main()
