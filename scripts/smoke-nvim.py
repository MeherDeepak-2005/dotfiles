"""Install the real plugin set in temporary XDG dirs, without touching the user's editor."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent


def run_editor(args, env, timeout):
    result = subprocess.run(args, env=env, timeout=timeout, text=True, capture_output=True)
    if result.returncode:
        # Git progress can be very large; retain the useful end of the diagnostic.
        print((result.stdout + result.stderr)[-8000:])
        raise subprocess.CalledProcessError(result.returncode, args)


with tempfile.TemporaryDirectory(prefix="dotfiles-nvim-") as temp:
    base = Path(temp)
    env = os.environ.copy()
    env.update({"XDG_CONFIG_HOME": str(base / "config"), "XDG_DATA_HOME": str(base / "data"),
                "XDG_STATE_HOME": str(base / "state"), "XDG_CACHE_HOME": str(base / "cache"),
                "DOTFILES_PLUGIN_MODE": "restore", "NVIM_APPNAME": "nvim"})
    config = base / "config/nvim"
    shutil.copytree(root / "config/nvim", config)
    run_editor(["nvim", "--headless", "-u", str(config / "init.lua"), "-l", str(root / "scripts/plugins.lua")], env, 300)
    # Exercise lazy-loaded plugins, not just bootstrap and colorscheme loading.
    check = base / "verify.lua"
    check.write_text('''assert(vim.g.colors_name == "rose-pine", "Rose Pine colorscheme was not loaded")
assert(require("oil"))
assert(require("neogit"))
assert(require("gitsigns"))
assert(require("which-key"))
assert(require("snacks"))
print("Neovim theme and plugin smoke test passed")
''')
    run_editor(["nvim", "--headless", "-u", str(config / "init.lua"), "-l", str(check)], env, 60)
    print("Isolated Neovim plugin installation, theme, and lazy-loaded plugins passed.")
