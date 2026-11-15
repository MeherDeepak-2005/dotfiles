"""Validate the rendered config and real pane commands in an isolated tmux/psmux server."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import uuid

root = Path(__file__).resolve().parent.parent
windows = os.name == "nt"
binary = shutil.which("psmux" if windows else "tmux")
if not binary:
    raise SystemExit("Install psmux (Windows) or tmux (Unix) to run this smoke test")
label = "dotfiles-test-" + uuid.uuid4().hex[:12]
base_command = [binary, "-L", label]


def command(*args, check=True):
    result = subprocess.run(base_command + list(args), text=True, encoding="utf-8", errors="replace", capture_output=True, timeout=20)
    if check and result.returncode:
        raise RuntimeError("Multiplexer command failed: " + repr(args) + "\n" + result.stdout + result.stderr)
    return result


with tempfile.TemporaryDirectory(prefix="dotfiles-mux-") as temp:
    config = Path(temp) / "test config.conf"
    shell = shutil.which("cmd.exe") if windows else "/bin/sh"
    subprocess.run(["python3", str(root / "scripts/render-config.py"),
                    "--platform", "windows" if windows else "linux",
                    "--shell", shell, "--entry", str(config), "--output", str(config)], check=True)
    started = False
    try:
        command("-f", str(config), "new-session", "-d", "-s", "dotfiles-test")
        started = True
        # psmux can return before startup config commands have all been applied.
        deadline = time.monotonic() + 15
        while True:
            result = command("list-keys", "-T", "root", "M-v", check=False)
            if result.returncode == 0 and "split-window" in result.stdout:
                break
            if time.monotonic() >= deadline:
                raise AssertionError("Alt+V binding did not load: " + result.stderr)
            time.sleep(0.2)
        # source-file reports errors synchronously, including unsupported config commands.
        result = command("source-file", str(config), check=False)
        assert result.returncode == 0, result.stdout + result.stderr
        for key, direction in [("h", "L"), ("j", "D"), ("k", "U"), ("l", "R")]:
            result = command("list-keys", "-T", "root", "M-" + key)
            assert "select-pane -" + direction in result.stdout, result.stdout
        command("split-window", "-h", "-t", "dotfiles-test", "-c", temp)
        command("split-window", "-v", "-t", "dotfiles-test", "-c", temp)
        panes = command("list-panes", "-t", "dotfiles-test", "-F", "#{pane_id}").stdout.strip().splitlines()
        assert len(panes) == 3, panes
        print("Real multiplexer config, Alt bindings, and both split directions passed: " + binary)
    finally:
        if started:
            command("kill-server", check=False)
