---@class helper
local M = {}

-- Check the number of characters on the display
---@param string string
---@param column integer
---@return integer charwidth
function M.charwidth(string, column)
  return vim.api.nvim_strwidth(vim.fn.strcharpart(string, column, 1, true))
end

-- Determines whether the specified string indicates a blockwise.
---@param mode? string
---@return boolean
function M.is_blockwise(mode)
  mode = mode or vim.api.nvim_get_mode().mode
  return mode:find('\x16', 1, true) ~= nil
end

return M
