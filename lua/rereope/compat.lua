--NOTE: This module is provided to ensure compatibility with version 0.11.

local M = {}

---@alias Encoding 'utf-8'|'utf-16'|'utf-32'

local has_next_version = vim.fn.has('nvim-0.12') == 1

---@param name string Argument name
---@param value any Argument value
---@param validator vim.validate.Validator
---@param optional boolean? Argument is optional
---@param message string? message when validation fails
function M.validate(name, value, validator, optional, message)
  if has_next_version then
    vim.validate(name, value, validator, optional, message)
  else
    vim.validate({ name = { value, validator, optional } })
  end
end

local _str_utfindex = vim.str_utfindex

---@param s string
---@param encoding Encoding
---@param index? integer
---@param strict_indexing? boolean
---@return integer
function M.str_utfindex(s, encoding, index, strict_indexing)
  if has_next_version then
    return _str_utfindex(s, encoding, index, strict_indexing)
  else
    return _str_utfindex(s, index)
  end
end

return M
