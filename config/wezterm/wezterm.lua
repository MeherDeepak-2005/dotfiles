local wezterm = require("wezterm")

local config = wezterm.config_builder()
local platform = dofile(wezterm.config_dir .. "/platform.lua")

-- Send both Option keys as Alt/Meta for tmux shortcuts.
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false

config.color_scheme = "rose-pine-moon"
config.font = wezterm.font("Hack Nerd Font")
config.font_size = 15.0
config.window_background_opacity = 0.8
if wezterm.target_triple:find("apple") then
  config.macos_window_background_blur = 50
end
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"

-- Close windows and tabs without an "are you sure?" prompt. The window setting
-- covers the close button; the default close-tab keys ask separately.
config.window_close_confirmation = "NeverPrompt"
config.keys = {
  { key = "w", mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentTab({ confirm = false }) },
  { key = "w", mods = "SUPER", action = wezterm.action.CloseCurrentTab({ confirm = false }) },
}

if platform.platform == "windows" then
  -- Windows renders points at 96 DPI (macOS at 72), so 15pt looks ~33% larger.
  -- 10.5pt is 30% smaller than the macOS size.
  config.font_size = 10.5
  -- Without a title bar or tab bar there is nothing to drag the window by.
  -- Keep the tab bar visible and put the min/max/close buttons in it; drag the
  -- window by the empty part of the tab bar.
  config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
  config.hide_tab_bar_if_only_one_tab = false
  -- Windows has no blur-radius setting; Acrylic is the system's frosted-glass
  -- backdrop. A lower opacity lets more of the blur show through.
  config.win32_system_backdrop = "Acrylic"
  config.window_background_opacity = 0.65
end

-- Dim unfocused windows so the focused one is obvious at a glance.
local UNFOCUSED_FOREGROUND_TEXT_HSB = { hue = 1.0, saturation = 0.25, brightness = 0.45 }
-- Stay below the focused opacity on every platform.
local UNFOCUSED_WINDOW_BACKGROUND_OPACITY = platform.platform == "windows" and 0.5 or 0.62

-- get_config_overrides() hands back a copy, so the current value is never the
-- same table we last stored; compare the fields instead of the identity.
local function same_text_hsb(actual, expected)
	if actual == nil or expected == nil then
		return actual == expected
	end
	return actual.hue == expected.hue
		and actual.saturation == expected.saturation
		and actual.brightness == expected.brightness
end

wezterm.on("window-focus-changed", function(window)
	local overrides = window:get_config_overrides() or {}
	local text_hsb, opacity
	if not window:is_focused() then
		text_hsb = UNFOCUSED_FOREGROUND_TEXT_HSB
		opacity = UNFOCUSED_WINDOW_BACKGROUND_OPACITY
	end

	-- Only write when one of the two values we own actually changes; a redundant
	-- set_config_overrides() call would trigger another config reload.
	if same_text_hsb(overrides.foreground_text_hsb, text_hsb) and overrides.window_background_opacity == opacity then
		return
	end

	overrides.foreground_text_hsb = text_hsb
	overrides.window_background_opacity = opacity
	window:set_config_overrides(overrides)
end)

config.default_prog = { platform.shell, "-l" }
if platform.platform == "windows" then
  config.default_prog = { platform.shell, "--login", "-i" }
end
return config
