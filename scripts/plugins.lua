-- Run with nvim --headless -l scripts/plugins.lua (uses the deployed init.lua).
local ok, err = xpcall(function()
  local lazy = require("lazy")
  local mode = vim.env.DOTFILES_PLUGIN_MODE or "sync"
  assert(mode == "sync" or mode == "restore", "Invalid plugin operation")
  lazy[mode]({ wait = true, show = false })
  local failed = {}
  for name, plugin in pairs(require("lazy.core.config").plugins) do
    if not vim.uv.fs_stat(plugin.dir) then
      table.insert(failed, name .. ": plugin directory missing")
    end
    for _, task in ipairs(plugin._.tasks or {}) do
      if task:has_errors() then
        table.insert(failed, name .. ": " .. task.name)
      end
    end
  end
  assert(#failed == 0, "Plugin installation failed: " .. table.concat(failed, ", "))
end, debug.traceback)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
