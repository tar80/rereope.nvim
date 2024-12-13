local M = {}

local INFOTIP_DEFAULT = {
  relative = 'cursor',
  anchor = 'NW',
  row = 0,
  col = 0,
  focusable = false,
  zindex = 200,
  style = 'minimal',
  border = { '', '', '', ' ', '', '', '', '>' },
  noautocmd = true,
}

---@package
---@param contents string|string[]
---@return boolean? has_contents, {height:integer,width:integer}?
local function get_winsize(contents)
  if type(contents) == 'table' and not table.concat(contents, ''):match('^%s*$') then
    local width = 1
    local height = 0
    for _, value in pairs(contents) do
      width = math.max(width, vim.api.nvim_strwidth(value))
      height = height + 1
    end
    return true, { height = height, width = width }
  end
end

---@alias NorthSouth 'N'|'S'

---@package
---@param winheight integer
---@return string anchor,integer row,integer max_row
local function get_direction(winheight)
  ---@type NorthSouth,integer,integer
  local place_ns, row, max_row
  local screenrow = vim.fn.screenrow() - 1
  local s_row = screenrow
  local e_row = vim.api.nvim_get_option_value('lines', { scope = 'global' })
  local laststatus = vim.api.nvim_get_option_value('laststatus', { scope = 'global' }) == 0 and 0 or 1
  local showtabline = vim.api.nvim_get_option_value('showtabline', { scope = 'global' }) == 0 and 0 or 1
  local cmdheight = vim.api.nvim_get_option_value('cmdheight', { scope = 'global' })
  e_row = e_row - laststatus - showtabline - cmdheight
  if e_row < (s_row + winheight) and (e_row / 2) < s_row then
    place_ns, row, max_row = 'S', 0, screenrow - showtabline
  else
    place_ns, row, max_row = 'N', 1, e_row - screenrow
  end
  return ('%sW'):format(place_ns), row, max_row
end

---@param ns integer Namespace
---@param contents string[]
---@param opts {winblend?:integer,border?:string[]}
function M.infotip(ns, contents, opts)
  local has_contents, winsize = get_winsize(contents)
  if not has_contents then
    return
  end
  ---@cast winsize -nil
  local anchor, row, max_row = get_direction(winsize.height)
  local float_conf = INFOTIP_DEFAULT
  float_conf.height = math.min(max_row, winsize.height)
  float_conf.width = winsize.width
  float_conf.row = row
  float_conf.anchor = anchor
  float_conf.border = opts.border or float_conf.border
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, winsize.height, false, contents)
  local winid = vim.api.nvim_open_win(bufnr, false, float_conf)
  local winblend = opts.winblend or vim.api.nvim_get_option_value('winblend', { scope = 'global' })
  vim.api.nvim_win_set_hl_ns(winid, ns)
  vim.api.nvim_set_option_value('winblend', winblend, { win = winid })
  return { bufnr, winid }
end

return M
