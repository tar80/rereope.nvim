---@meta helper
---@class helper
local M = {}

---@alias LogLevels 'TRACE'|'DEBUG'|'INFO'|'WARN'|'ERROR'|'OFF'

-- Get the current utf encoding
---@param encoding? string
---@return string encoding
function M.utf_encoding(encoding)
  encoding = string.lower(encoding or '')
  if encoding == 'utf-8' or encoding == 'utf-16' then
    return encoding
  end
  return 'utf-32'
end

-- Check the number of characters on the display
---@param string string
---@param column integer
---@return integer charwidth
function M.charwidth(string, column)
  return vim.api.nvim_strwidth(vim.fn.strcharpart(string, column, 1, 1))
end

return M
