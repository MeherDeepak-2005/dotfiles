local root = assert(arg[1], "Pass the repository directory")
local files = vim.fn.glob(root .. "/config/**/*.lua", false, true)
vim.list_extend(files, vim.fn.glob(root .. "/scripts/*.lua", false, true))
for _, file in ipairs(files) do
  assert(loadfile(file))
end
print("Parsed " .. #files .. " Lua files")
