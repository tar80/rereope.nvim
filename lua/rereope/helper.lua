---@meta helper
---@class helper
local M = {}

---@alias LogLevels 'TRACE'|'DEBUG'|'INFO'|'WARN'|'ERROR'|'OFF'

-- Get the current utf encoding
---@param encoding? string
---@return string UtfEncoding
function M.utf_encoding(encoding)
  encoding = string.lower(encoding or vim.bo.fileencoding)
  local has_match = ('utf-16,utf-32'):find(encoding, 1, true) ~= nil
  return has_match and encoding or 'utf-8'
end

-- Check the number of characters on the display
---@param string string
---@param column integer
---@return integer charwidth
function M.charwidth(string, column)
  return vim.api.nvim_strwidth(vim.fn.strcharpart(string, column, 1))
end

return M
