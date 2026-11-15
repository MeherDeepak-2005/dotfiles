# Meher's dotfiles

[![Validate dotfiles](https://github.com/MeherDeepak-2005/dotfiles/actions/workflows/validate.yml/badge.svg?branch=main)](https://github.com/MeherDeepak-2005/dotfiles/actions/workflows/validate.yml)

One installer for the same Rose Pine Moon terminal/editor workflow on macOS,
Linux, and **native Windows**. Windows uses **psmux**, not WSL. macOS/Linux use tmux.

## Install

On macOS, Linux, or **Git Bash on Windows**, run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/MeherDeepak-2005/dotfiles/main/startup.sh)
```

The command detects the OS, installs its package manager if needed, downloads
this repository, installs missing tools, upgrades outdated managed tools, deploys
configuration, and installs/updates Neovim plugins. Open a new WezTerm window when
it finishes, then run `tmux` on Mac/Linux or `psmux` on Windows.

If you've already cloned the repository:

```bash
bash startup.sh
```

### A completely fresh Windows computer

Windows does not ship Bash. Run this **once in a normal PowerShell window**:

```powershell
& ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/MeherDeepak-2005/dotfiles/main/bootstrap.ps1')))
```

It installs Git for Windows (including Git Bash) through winget if missing, then
runs `startup.sh`. Git's installer may show an administrator prompt. The rest runs
as your ordinary user through Scoop. A missing Microsoft Visual C++ runtime is
also installed and may show an administrator prompt. No WSL, virtual machine,
Linux filesystem, or administrator shell is needed. If winget is absent, install Microsoft's
[App Installer](https://apps.microsoft.com/detail/9nblggh4nns1) or
[Git for Windows](https://git-scm.com/download/win), then rerun.

Subsequent installs/updates use the same Bash command as the other platforms.

### Requirements

- A supported 64-bit macOS, or a glibc-based Linux distribution supported by
  [Homebrew](https://docs.brew.sh/Support-Tiers). Apple Silicon and Intel Macs are
  detected automatically. Homebrew chooses the matching CPU packages.
- Native 64-bit Windows 10/11 with Git Bash and PowerShell 5.1+. Windows ARM64
  depends on package availability/x64 emulation (not every dependency ships ARM64).
- Internet access and an interactive terminal. Linux Homebrew bootstrap and Mac
  developer tools may need a password. Don't launch the whole script with sudo.
- Bash and curl for the download command. Minimal Linux images without curl must
  install it using their system package manager first.

Linux bootstrap supports apt, dnf, pacman, and zypper. It installs compiler/build
prerequisites for Homebrew. Unsupported distributions fail with instructions;
Alpine/musl and NixOS are not automatic installation targets. A Linux desktop is
needed to display WezTerm; command-line programs can still be used on a server.

## What is included

| Component | macOS / Linux | Native Windows |
| --- | --- | --- |
| Terminal | WezTerm | WezTerm |
| Multiplexer | tmux | psmux (`tmux` alias also supplied by its package) |
| Shell | zsh, autosuggestions, syntax highlighting | Git Bash, portable aliases and navigation helpers |
| Editor | Neovim, lazy.nvim, bundled plugin configuration | Native Neovim with the same plugin configuration |
| Appearance | Rose Pine Moon, Hack Nerd Font, Starship | Same colors, font, and prompt |
| CLI tools | git, eza, fd, ripgrep, fzf, Python, Lua, LuaRocks | Same native tools |

The editor includes Oil, Snacks picker/notifier/input, Which-Key, Neogit,
Gitsigns, Diffview, Plenary, and Rose Pine. Neovim embeds its own Lua runtime;
standalone Lua/LuaRocks are also installed. The current plugin set doesn't need
additional rock packages. It does not configure language servers: `gd` requires
an attached LSP server if you add one later.

WezTerm preserves the current font size, translucency, and dimming of unfocused
windows. Both Mac Option keys send Alt/Meta. The installer detects your actual
shell executable, rather than assuming `/bin/zsh` or `C:\Program Files\Git`.
macOS-only blur settings are applied only on macOS.

Personal command-line apps, credentials, histories, Git identity, Anaconda,
old Python framework paths, and machine-specific IDE paths are not copied.
An existing Anaconda install is detected by the zsh configuration.

### Why psmux on Windows?

psmux runs natively on Windows and supports tmux-style configuration, commands,
panes, and persistent sessions. This bundle uses tmux on macOS/Linux and psmux
on Windows, with one shared set of bindings and platform-specific shell settings.
Windows files stay on the Windows filesystem; no WSL environment is involved.

The project's [published performance measurements](https://github.com/psmux/psmux/blob/master/docs/performance.md)
report low multiplexer overhead, with shell startup contributing much of the
time needed to open a pane. Those measurements are not a direct comparison with
tmux on your hardware, so equivalent performance is not guaranteed. WezTerm's
GPU acceleration affects terminal rendering, not filesystem or Git performance.

## Existing configs: your choice

Before replacing a differing configuration path, the installer offers:

1. **Keep** (default): leave it untouched.
2. **Back up and replace**: move the whole old path into a timestamped backup,
   then copy in the bundled config. Old files don't get merged into the new one.
3. **Delete and replace**: require you to type `DELETE` plus the exact path shown,
   then remove that specific file/directory and install a clean copy.

It never clears your whole `~/.config`, home directory, or unrelated apps.
Identical configs are skipped without a prompt. Existing `.wezterm.lua` files
are handled separately because they can override `.config/wezterm`.

Managed paths:

| Platform | Paths |
| --- | --- |
| All | `$XDG_CONFIG_HOME/wezterm`, `$XDG_CONFIG_HOME/starship.toml` (defaults to `~/.config`) |
| macOS / Linux | `$XDG_CONFIG_HOME/nvim`, `$XDG_CONFIG_HOME/tmux`, `~/.tmux.conf`, `~/.zshrc` |
| Windows | Native Neovim's detected config directory (normally `%LOCALAPPDATA%\nvim`), `~/.psmux.conf`, `~/.bashrc`, `~/.bash_profile` |

Backups mirror the original path under
`~/.local/state/dotfiles/backups/<timestamp>-<process>/`. To restore, move the
installed config aside and move its backup back to the original location.
Only remove a backup after you're satisfied with the new setup.

Config files are **copies**, not symlinks. Editor/plugin updates cannot dirty the
repository. Machine-specific shell additions belong in `~/.zshrc.local` or
`~/.bashrc.local`; these are outside the installer-managed paths.

Keeping an existing Neovim config also skips plugin installation for that config.
Declining removal of an overriding WezTerm file leaves it in place and prints a
warning: that file may continue to determine what WezTerm loads.

## Updates and package detection

Run the download command again to fetch the latest clean `main` checkout and
repeat setup. If running from your own clone, first `git pull --ff-only`, then
`bash startup.sh`. The downloaded checkout lives at
`${XDG_DATA_HOME:-~/.local/share}/meher-dotfiles`. Dirty checkouts are never reset.

- **Mac/Linux:** Homebrew refreshes metadata, installs missing managed packages,
  and upgrades only the outdated packages in this setup. Linux uses WezTerm's
  official Linuxbrew tap. Hack Nerd Font is version-checked; Linux downloads are
  verified against the release asset's SHA-256 digest.
- **Windows:** Scoop updates its manifests, installs missing packages, and skips
  managed packages already at the available version. WezTerm comes from
  `extras`, psmux from its project's bucket, and Hack from `nerd-fonts`.
- **Windows tools installed outside Scoop:** the installer detects executables
  on PATH and asks whether to keep them or add a Scoop-managed copy. Keeping them
  leaves their updates to their original installer/package manager. The script
  does not silently uninstall or take over another manager's installations.
- **Unix tools outside Homebrew:** a Homebrew-managed toolchain is installed and
  placed first on PATH. Other installations are not removed. Updates are to the
  package manager's available stable versions, not arbitrary nightly builds.
- **Neovim:** default setup synchronizes plugins to their available updates.
  `--locked-plugins` instead restores the bundled `lazy-lock.json` versions.
  Plugin changes update the deployed lockfile; a later run may therefore offer
  replacement again. A plugin download/build failure makes setup fail visibly.

WezTerm or plugins can require a restart after an upgrade. No running multiplexer
sessions are killed or reloaded by the installer. New sessions load the new config;
for an existing session use backtick then `r`.

## Shortcuts

Option on Mac is Alt on Windows/Linux. These are shared between tmux and psmux:

| Action | Shortcut |
| --- | --- |
| Move left / down / up / right | Alt + H / J / K / L |
| Create side-by-side panes | Alt + V |
| Create top/bottom panes | Backtick, then Y |
| Create side-by-side panes (prefix form) | Backtick, then V or `\|` |
| Create top/bottom panes (alias) | Backtick, then `-` |
| New window | Backtick, then C |
| Zoom current pane | Backtick, then Z |
| Reload multiplexer config | Backtick, then R |
| Detach session | Backtick, then D |
| Type a literal backtick | Backtick twice |

Letters above are lowercase keypresses unless Shift is explicitly shown.
Alt+Y is intentionally **not** bound because it conflicts with shell paste cycling.
Any root-level Alt binding takes priority over the application inside a pane.
WezTerm itself does not intercept these pane shortcuts.

The Windows config uses psmux's native shell/clipboard settings and omits Unix
terminfo settings. Platform configs are rendered from
`config/multiplexer/shared.conf` so navigation, splits, and theme stay in sync.
psmux aims for tmux compatibility, but is a separate implementation: platform
behavior and third-party plugins are not assumed identical. No tmux plugins are
required by this bundle.

Neovim: Space is the leader; Space+E opens Oil, Space+F finds files, Space+S
searches text, Space+B lists buffers, Space+G opens Neogit, Escape saves, and
Ctrl+A selects all. Shell: `ll`, `la`, `lt`, `ltt`, `z <name>`, and `zi` preserve
the listing/navigation workflow.

## Preview and optional flags

```bash
bash startup.sh --dry-run
bash startup.sh --existing backup
bash startup.sh --existing keep
bash startup.sh --locked-plugins
bash startup.sh --skip-packages --skip-plugins
```

`--dry-run` downloads/installs/writes nothing when run locally. Package managers
may still ask their normal installation questions during real setup. There is
no unattended deletion flag. With no terminal, a differing config causes an
error unless `--existing backup` or `--existing keep` was supplied.

## Validation

The implementation at commit `0938a0b` passed
[macOS, Linux, and native Windows validation](https://github.com/MeherDeepak-2005/dotfiles/actions/runs/43722185599),
including real tmux/psmux pane operations and isolated Neovim plugin installation.
The badge above links to the latest workflow status.

```bash
python3 -m unittest discover -s tests -v
nvim --headless -u NONE -l tests/lua-syntax.lua "$PWD"
nvim --headless -u NONE -l tests/wezterm.lua "$PWD"
python3 scripts/smoke-nvim.py
python3 scripts/smoke-multiplexer.py
```

Deployment tests use temporary paths to check replacement, exact deletion
confirmation, backups, symlink handling, paths with spaces, and repeat runs.
The editor smoke test downloads the real plugin set into temporary XDG
directories; it does not modify your normal Neovim setup. CI runs validation on
macOS, Linux, and Windows. These checks do not emulate every distribution's
fresh package-manager installation or benchmark Windows psmux on your hardware.
