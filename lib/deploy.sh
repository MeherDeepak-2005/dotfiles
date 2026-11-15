# Sourced by startup.sh and the isolated deployment tests.

validate_roots() {
  local value
  for value in "$HOME" "$CONFIG_HOME" "$DATA_HOME"; do
    case "$value" in
      ''|/|.|..|*/../*|*/..|*/./*|*/.) die "Unsafe install root: $value" ;;
      /*) ;;
      *) die "Install roots must be absolute paths: $value" ;;
    esac
  done
  [ "$CONFIG_HOME" != "$HOME" ] || die 'Config root must not equal your home directory.'
}

ask() {
  # Interactive replacement never assumes that a pipe's input is consent.
  if ! { printf '%s' "$1" >/dev/tty; } 2>/dev/null; then
    die 'A differing config needs a decision. Run interactively or use --existing backup/keep.'
  fi
  IFS= read -r ANSWER </dev/tty || die 'No answer received; nothing was replaced.'
}

prepare_destination() {
  local destination=$1 choice=$EXISTING
  if [ ! -e "$destination" ] && [ ! -L "$destination" ]; then return 0; fi
  case "$destination" in
    "$HOME"|"$CONFIG_HOME"|"$DATA_HOME"|/|'') die "Refusing to replace a root directory: $destination" ;;
  esac
  if [ "$choice" = prompt ]; then
    printf '\nExisting configuration: %s\n' "$destination"
    ask '[k]eep / [b]ack up and replace / [d]elete and replace [k]: '
    case "$ANSWER" in
      b|B|backup) choice=backup ;;
      d|D|delete)
        ask "Type DELETE $destination to permanently remove that path: "
        if [ "$ANSWER" = "DELETE $destination" ]; then choice=delete; else choice=keep; fi ;;
      *) choice=keep ;;
    esac
  fi
  case "$choice" in
    keep) log "Kept $destination"; return 1 ;;
    backup)
      # Mirror the absolute destination under a unique backup root, including symlinks.
      local backup="$BACKUP_ROOT/${destination#/}"
      mkdir -p -- "$(dirname -- "$backup")"
      mv -- "$destination" "$backup"
      log "Backed up $destination to $backup" ;;
    delete) rm -rf -- "$destination" ;;
    *) die "Invalid replacement policy: $choice" ;;
  esac
}

deploy() {
  local source=$1 destination=$2
  DEPLOYED=0
  if [ -e "$destination" ] && diff -qr -- "$source" "$destination" >/dev/null 2>&1; then
    log "Already current: $destination"
    DEPLOYED=1
    return 0
  fi
  if ! prepare_destination "$destination"; then return 0; fi
  mkdir -p -- "$(dirname -- "$destination")"
  cp -R -- "$source" "$destination"
  DEPLOYED=1
  log "Installed $destination"
}

disable_shadow() {
  # Older entry points otherwise take precedence over the installed main config.
  local destination=$1
  if [ -e "$destination" ] || [ -L "$destination" ]; then
    if ! prepare_destination "$destination"; then
      log "WARNING: $destination may override the new configuration."
    fi
  fi
}

deploy_configs() {
  NVIM_DEPLOYED=0
  command -v python3 >/dev/null 2>&1 || die 'Python 3 is required to render native config paths.'
  local staged shell_path entry_path
  staged=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-config.XXXXXX")
  STAGED_CONFIG=$staged
  trap 'rm -rf -- "$STAGED_CONFIG"' EXIT
  shell_path=$(command -v zsh) || shell_path=''
  if [ "$PLATFORM" = windows ]; then shell_path=$(cygpath -m "$(command -v bash)"); fi
  [ -n "$shell_path" ] || die 'The configured shell is missing.'
  cp -R "$REPO_DIR/config/wezterm" "$staged/wezterm"
  python3 - "$shell_path" "$PLATFORM" "$staged/wezterm/platform.lua" <<'PY'
import json
import sys
from pathlib import Path
Path(sys.argv[3]).write_text('return { shell = ' + json.dumps(sys.argv[1], ensure_ascii=False) + ', platform = ' + json.dumps(sys.argv[2]) + ' }\n', encoding='utf-8')
PY
  deploy "$staged/wezterm" "$CONFIG_HOME/wezterm"
  if [ "$DEPLOYED" -eq 1 ]; then disable_shadow "$HOME/.wezterm.lua"; fi
  deploy "$REPO_DIR/config/starship.toml" "$CONFIG_HOME/starship.toml"
  if [ "$PLATFORM" = windows ]; then
    command -v nvim >/dev/null 2>&1 || die 'Native Neovim is needed to locate its Windows config directory.'
    local nvim_config
    nvim_config=$(nvim --headless -u NONE -i NONE -c 'lua io.write(vim.fn.stdpath("config"))' -c qa | tr -d '\r')
    [ -n "$nvim_config" ] || die 'Could not determine native Neovim config directory.'
    nvim_config=$(cygpath -u "$nvim_config")
    deploy "$REPO_DIR/config/nvim" "$nvim_config"
    NVIM_DEPLOYED=$DEPLOYED
    NVIM_CONFIG_FILE="$nvim_config/init.lua"
    shell_path=$(cygpath -m "$(command -v bash)")
    entry_path=$(cygpath -m "$HOME/.psmux.conf")
    python3 "$REPO_DIR/scripts/render-config.py" --platform "$PLATFORM" --shell "$shell_path" --entry "$entry_path" --output "$staged/psmux.conf"
    deploy "$staged/psmux.conf" "$HOME/.psmux.conf"
    deploy "$REPO_DIR/config/bashrc" "$HOME/.bashrc"
    deploy "$REPO_DIR/config/bash_profile" "$HOME/.bash_profile"
  else
    deploy "$REPO_DIR/config/nvim" "$CONFIG_HOME/nvim"
    NVIM_DEPLOYED=$DEPLOYED
    NVIM_CONFIG_FILE="$CONFIG_HOME/nvim/init.lua"
    shell_path=$(command -v zsh) || die 'zsh is required for the Unix multiplexer config.'
    mkdir -p "$staged/tmux"
    python3 "$REPO_DIR/scripts/render-config.py" --platform "$PLATFORM" --shell "$shell_path" --entry "$HOME/.tmux.conf" --output "$staged/tmux/tmux.conf"
    deploy "$staged/tmux" "$CONFIG_HOME/tmux"
    python3 - "$CONFIG_HOME/tmux/tmux.conf" "$staged/tmux-entry.conf" <<'PY'
import sys
from pathlib import Path
path = sys.argv[1].replace('\\', '\\\\').replace('$', '\\$').replace('"', '\\"')
Path(sys.argv[2]).write_text('source-file "' + path + '"\n')
PY
    deploy "$staged/tmux-entry.conf" "$HOME/.tmux.conf"
    deploy "$REPO_DIR/config/zshrc" "$HOME/.zshrc"
  fi
}
