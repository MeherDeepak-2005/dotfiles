install_brew_packages() {
  local package
  local missing=() outdated=()
  local formulas=(git neovim tmux zsh starship eza fd ripgrep fzf python lua luarocks
    zsh-autosuggestions zsh-syntax-highlighting)
  if [ "$PLATFORM" = linux ]; then
    brew tap wezterm/wezterm-linuxbrew
    formulas+=(wezterm/wezterm-linuxbrew/wezterm)
    # Clipboard support under X11 and Wayland; Neovim chooses the available provider.
    formulas+=(xclip wl-clipboard)
  fi
  for package in "${formulas[@]}"; do
    if ! brew list --formula --versions "$package" >/dev/null 2>&1; then missing+=("$package"); fi
  done
  if [ "${#missing[@]}" -gt 0 ]; then log 'Installing missing command-line packages.'; brew install --formula "${missing[@]}"; fi
  local outdated_output
  outdated_output=$(brew outdated --formula --quiet "${formulas[@]}")
  while IFS= read -r package; do
    [ -z "$package" ] || outdated+=("$package")
  done <<< "$outdated_output"
  if [ "${#outdated[@]}" -gt 0 ]; then
    log 'Upgrading outdated command-line packages.'
    brew upgrade --formula "${outdated[@]}"
  else
    log 'Command-line packages are current.'
  fi
  if [ "$PLATFORM" = macos ]; then
    for package in wezterm font-hack-nerd-font; do
      if ! brew list --cask --versions "$package" >/dev/null 2>&1; then
        brew install --cask "$package"
      elif [ -n "$(brew outdated --cask --quiet "$package")" ]; then
        brew upgrade --cask "$package"
      else
        log "Already current: $package"
      fi
    done
  fi
}

install_unix_font() {
  [ "$PLATFORM" = linux ] || return 0
  log 'Checking the Hack Nerd Font release.'
  python3 "$REPO_DIR/scripts/install-font.py"
  if command -v fc-cache >/dev/null 2>&1; then fc-cache -f "${XDG_DATA_HOME:-$HOME/.local/share}/fonts/HackNerdFont"; fi
}
