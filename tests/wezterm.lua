-- Exercise both native config branches without starting a terminal window.
local root = assert(arg[1], "Pass the repository directory")
local real_dofile = dofile
for _, osname in ipairs({ "macos", "linux", "windows" }) do
  local callbacks = {}
  local wezterm = {
    config_dir = "mock-config",
    target_triple = osname == "macos" and "aarch64-apple-darwin"
      or (osname == "windows" and "x86_64-pc-windows-msvc" or "x86_64-unknown-linux-gnu"),
    config_builder = function() return {} end,
    font = function(name) return name end,
    on = function(event, callback) callbacks[event] = callback end,
  }
  package.loaded.wezterm = wezterm
  local shell = osname == "windows" and "C:/Program Files/Git/bin/bash.exe" or "/test/bin/zsh"
  _G.dofile = function(path)
    if path == "mock-config/platform.lua" then return { platform = osname, shell = shell } end
    return real_dofile(path)
  end
  local config = real_dofile(root .. "/config/wezterm/wezterm.lua")
  assert(config.default_prog[1] == shell)
  assert(config.send_composed_key_when_left_alt_is_pressed == false)
  assert(config.send_composed_key_when_right_alt_is_pressed == false)
  assert(config.macos_window_background_blur == (osname == "macos" and 50 or nil))
  local override = {}
  local writes = 0
  local focused = false
  local window = {
    get_config_overrides = function() return override end,
    is_focused = function() return focused end,
    set_config_overrides = function(_, value) override = value; writes = writes + 1 end,
  }
  callbacks["window-focus-changed"](window)
  assert(writes == 1 and override.window_background_opacity == 0.62)
  callbacks["window-focus-changed"](window)
  assert(writes == 1, "Unchanged focus must not cause config reload loops")
  focused = true
  callbacks["window-focus-changed"](window)
  assert(writes == 2 and override.window_background_opacity == nil)
  print("WezTerm config passed: " .. osname)
end
_G.dofile = real_dofile
