#!/usr/bin/env bash
# Bash 3.2+ (including macOS's bundled Bash and Git Bash on Windows).
set -euo pipefail

log() { printf '\n[dotfiles] %s\n' "$*"; }
die() { printf '[dotfiles] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'HELP'
Usage: bash startup.sh [options]
  --dry-run          Print the plan without installing, downloading, or writing.
  --existing MODE    prompt (default), backup, or keep. Delete is interactive only.
  --skip-packages    Deploy config without installing or upgrading programs/fonts.
  --skip-plugins     Do not download or update Neovim plugins.
  --locked-plugins   Restore plugins to the bundled lazy-lock.json instead of updating.
  --help            Show this help.

Existing configs are never deleted without an exact, per-path confirmation.
Windows: run in Git Bash; bootstrap.ps1 installs Git Bash on a fresh Windows PC.
HELP
}

DRY_RUN=0
EXISTING=prompt
SKIP_PACKAGES=0
SKIP_PLUGINS=0
LOCKED_PLUGINS=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --existing)
      [ "$#" -ge 2 ] || die '--existing requires prompt, backup, or keep'
      EXISTING=$2; shift
      case "$EXISTING" in prompt|backup|keep) ;; *) die 'Invalid --existing mode' ;; esac ;;
    --skip-packages) SKIP_PACKAGES=1 ;;
    --skip-plugins) SKIP_PLUGINS=1 ;;
    --locked-plugins) LOCKED_PLUGINS=1 ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done

case "$(uname -s)" in
  Darwin) PLATFORM=macos ;;
  Linux)
    if [ -n "${WSL_DISTRO_NAME:-}" ]; then
      die 'This setup uses native Windows tools. Run startup.sh in Git Bash, not WSL.'
    fi
    PLATFORM=linux ;;
  MINGW*|MSYS*) PLATFORM=windows ;;
  *) die 'Supported platforms: macOS, Linux, and native Windows through Git Bash.' ;;
esac
case "$(uname -m)" in x86_64|amd64|arm64|aarch64) ;; *) die 'A 64-bit OS is required.' ;; esac

CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}
DATA_HOME=${XDG_DATA_HOME:-"$HOME/.local/share"}
if [ "$PLATFORM" = windows ]; then
  CONFIG_HOME=$(cygpath -u "$CONFIG_HOME")
  DATA_HOME=$(cygpath -u "$DATA_HOME")
fi
BACKUP_ROOT="$HOME/.local/state/dotfiles/backups/$(date +%Y%m%d-%H%M%S)-$$"
REPO_URL=https://github.com/MeherDeepak-2005/dotfiles.git
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$SCRIPT_DIR
if [ ! -f "$REPO_DIR/lib/deploy.sh" ]; then
  REPO_DIR="$DATA_HOME/meher-dotfiles"
fi

log "Platform: $PLATFORM ($(uname -m))"
if [ "$DRY_RUN" -eq 1 ]; then
  log 'DRY RUN: no files, packages, plugins, repositories, or shell settings will change.'
  printf 'Repository: %s\nConfig root: %s\nConflict policy: %s\n' "$REPO_DIR" "$CONFIG_HOME" "$EXISTING"
  if [ "$SKIP_PACKAGES" -eq 0 ]; then
    case "$PLATFORM" in
      windows) log 'Install/update Scoop packages: WezTerm, psmux, Git, Neovim, Lua/LuaRocks, Starship, eza, fd, ripgrep, fzf, Python, Hack Nerd Font.' ;;
      *) log 'Install/update Homebrew packages: WezTerm, tmux, zsh, Neovim, Lua/LuaRocks, Starship, eza, fd, ripgrep, fzf, Python, zsh plugins, Hack Nerd Font.' ;;
    esac
  fi
  log 'Deploy WezTerm, editor, shell, prompt, and OS-specific multiplexer config; prompt for differing existing paths.'
  [ "$SKIP_PLUGINS" -eq 1 ] || log 'Install/synchronize the bundled Neovim plugin set.'
  exit 0
fi

# An ordinary user owns their config and Homebrew/Scoop installation.
[ "$(id -u)" -ne 0 ] || die 'Run as your normal user, without sudo.'
for root_path in "$HOME" "$CONFIG_HOME" "$DATA_HOME"; do
  case "$root_path" in
    ''|/|.|..|*/../*|*/..|*/./*|*/.) die "Unsafe install root: $root_path" ;;
    /*) ;;
    *) die "Install roots must be absolute paths: $root_path" ;;
  esac
done
[ "$CONFIG_HOME" != "$HOME" ] || die 'Config root must not equal your home directory.'

as_root() {
  command -v sudo >/dev/null 2>&1 || die 'sudo is required to install Linux bootstrap dependencies.'
  sudo "$@"
}

bootstrap_brew() {
  local candidate
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    if [ -x "$candidate" ]; then eval "$("$candidate" shellenv)"; break; fi
  done
  if ! command -v brew >/dev/null 2>&1; then
    if [ "$PLATFORM" = linux ]; then
      if command -v apt-get >/dev/null 2>&1; then
        as_root apt-get update
        as_root apt-get install -y build-essential procps curl file git ca-certificates
      elif command -v dnf >/dev/null 2>&1; then
        as_root dnf install -y gcc gcc-c++ make procps-ng curl file git which tar gzip
      elif command -v pacman >/dev/null 2>&1; then
        as_root pacman -Syu --needed --noconfirm base-devel procps-ng curl file git
      elif command -v zypper >/dev/null 2>&1; then
        as_root zypper --non-interactive install gcc gcc-c++ make procps curl file git tar gzip
      else
        die 'Install Homebrew and its build prerequisites first on this Linux distribution.'
      fi
    fi
    command -v curl >/dev/null 2>&1 || die 'curl is needed to bootstrap Homebrew.'
    log 'Installing Homebrew from its official installer (may request your password).'
    local installer
    installer=$(mktemp "${TMPDIR:-/tmp}/dotfiles-homebrew.XXXXXX")
    curl --fail --show-error --location --retry 3 https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"
    /bin/bash "$installer"
    rm -f -- "$installer"
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
      if [ -x "$candidate" ]; then eval "$("$candidate" shellenv)"; break; fi
    done
  fi
  command -v brew >/dev/null 2>&1 || die 'Homebrew installation did not produce a usable brew command.'
  export HOMEBREW_NO_AUTO_UPDATE=1
}

if [ "$PLATFORM" != windows ] && [ "$SKIP_PACKAGES" -eq 0 ]; then
  bootstrap_brew
  log 'Refreshing Homebrew package metadata.'
  brew update
  # Git is required even when invoked as a standalone downloaded script.
  if ! command -v git >/dev/null 2>&1; then brew install git; fi
fi

if [ ! -f "$REPO_DIR/lib/deploy.sh" ]; then
  command -v git >/dev/null 2>&1 || die 'Git is missing. On Windows, run bootstrap.ps1 first.'
  if [ -e "$REPO_DIR" ]; then
    [ -d "$REPO_DIR/.git" ] || die "Repository destination already exists and is not a Git checkout: $REPO_DIR"
    [ "$(git -C "$REPO_DIR" remote get-url origin)" = "$REPO_URL" ] || die 'Existing checkout has a different origin.'
    [ -z "$(git -C "$REPO_DIR" status --porcelain)" ] || die "Commit/stash your dotfiles checkout changes before updating: $REPO_DIR"
    git -C "$REPO_DIR" pull --ff-only origin main
  else
    mkdir -p -- "$(dirname -- "$REPO_DIR")"
    git clone --branch main "$REPO_URL" "$REPO_DIR"
  fi
  # Re-enter the downloaded version so code and configuration come from one revision.
  args=(--existing "$EXISTING")
  [ "$SKIP_PACKAGES" -eq 0 ] || args+=(--skip-packages)
  [ "$SKIP_PLUGINS" -eq 0 ] || args+=(--skip-plugins)
  [ "$LOCKED_PLUGINS" -eq 0 ] || args+=(--locked-plugins)
  exec bash "$REPO_DIR/startup.sh" "${args[@]}"
fi

# shellcheck source=lib/deploy.sh
source "$REPO_DIR/lib/deploy.sh"
# shellcheck source=lib/packages.sh
source "$REPO_DIR/lib/packages.sh"

validate_roots
if [ "$SKIP_PACKAGES" -eq 0 ]; then
  if [ "$PLATFORM" = windows ]; then
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$REPO_DIR/scripts/windows-packages.ps1")"
    # This Bash process predates Scoop's PATH update.
    SCOOP_HOME=$(powershell.exe -NoProfile -Command 'if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE "scoop" }' | tr -d '\r')
    export PATH="$(cygpath -u "$SCOOP_HOME")/shims:$PATH"
  else
    install_brew_packages
    install_unix_font
  fi
fi

deploy_configs
if [ "$SKIP_PLUGINS" -eq 0 ] && [ "$NVIM_DEPLOYED" -eq 1 ]; then
  command -v nvim >/dev/null 2>&1 || die 'Neovim is missing; install packages or pass --skip-plugins.'
  export DOTFILES_PLUGIN_MODE=sync
  [ "$LOCKED_PLUGINS" -eq 0 ] || export DOTFILES_PLUGIN_MODE=restore
  log "Installing Neovim plugins ($DOTFILES_PLUGIN_MODE)."
  # -l exits nonzero when the Lua script reports a failed plugin task.
  nvim --headless -u "$NVIM_CONFIG_FILE" -l "$REPO_DIR/scripts/plugins.lua"
elif [ "$NVIM_DEPLOYED" -eq 0 ]; then
  log 'Kept your existing Neovim config; its plugins were not touched.'
fi

log 'Setup complete. Open a new WezTerm window.'
if [ "$PLATFORM" = windows ]; then
  printf 'Run psmux (or tmux) for panes and persistent sessions. Windows uses Git Bash, without WSL.\n'
else
  printf 'Run tmux for panes and persistent sessions. WezTerm launches the installed zsh.\n'
fi
printf 'Existing configs selected for backup are under: %s\n' "$BACKUP_ROOT"
printf 'Pane movement: Alt/Option+H/J/K/L. Split side-by-side: Alt/Option+V.\n'
printf 'Split top/bottom: backtick, then Y. Other existing backtick commands are preserved.\n'
