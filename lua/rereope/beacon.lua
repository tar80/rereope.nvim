---@class Beacon:BeaconInstance
---@field new fun(hl:string,interval:integer,blend:integer,decay:integer):BeaconInstance
---@field around_cursor? fun(self,winid:integer)
---@field replaced_region fun(self,regcontents:string,height:integer,end_point:boolean)

---@class BeaconInstance
---@field timer uv.uv_timer_t
---@field is_running boolean
---@field hlgroup string
---@field interval integer
---@field blend integer
---@field decay integer

---@class Beacon
local M = {}
local helper = require('rereope.helper')

---@private
local DEFAULT_OPTIONS = {
  relative = 'win',
  height = 1,
  focusable = false,
  noautocmd = true,
  border = false,
  style = 'minimal',
}

---@param hlgroup string Hlgroup
---@param interval integer repeat interval
---@param blend integer Initial value of winblend
---@param decay integer winblend becay
function M.new(hlgroup, interval, blend, decay)
  vim.validate('hlgroup', hlgroup, 'string', true)
  vim.validate('interval', interval, 'number', true)
  vim.validate('blend', blend, 'number', true)
  vim.validate('decay', decay, 'number', true)
  return setmetatable({
    timer = assert(vim.uv.new_timer()),
    is_running = false,
    hlgroup = hlgroup or 'IncSearch',
    interval = interval or 100,
    blend = blend or 0,
    decay = decay or 15,
  }, { __index = M })
end

---@alias WindowRelative 'editor'|'win'|'cursor'|'mouse'
---@alias WindowRegion {height:integer,width:integer,row:integer,col:integer,relative:WindowRelative}

---@param text string The text that was replaced.
---@param height integer The height of the replaced region.
---@param end_point boolean Indicates whether the replacement happened at the end of a line.
function M:replaced_region(text, height, end_point)
  local textwidth = vim.api.nvim_strwidth(text)
  local cur_charwidth = helper.charwidth(text, 0)
  local region = {
    height = height,
    width = textwidth,
    row = end_point and (1 - height) or 0,
    col = end_point and (cur_charwidth - textwidth) or 0,
    relative = 'cursor',
  }
  self:flash(region)
end

-- Flash around the cursor position
---@param region {height:integer,width:integer,row:integer,col:integer,relative?:string}
function M:flash(region)
  if not self.is_running then
    self.is_running = true
    vim.schedule(function()
      local opts = vim.tbl_extend('force', DEFAULT_OPTIONS, region)
      local bufnr = vim.api.nvim_create_buf(false, true)
      self.winid = vim.api.nvim_open_win(bufnr, false, opts)
      vim.api.nvim_set_option_value(
        'winhighlight',
        ('Normal:%s,EndOfBuffer:%s'):format(self.hlgroup, self.hlgroup),
        { win = self.winid }
      )
      vim.api.nvim_set_option_value('winblend', self.blend, { win = self.winid })
      self.timer:start(
        0,
        self.interval,
        vim.schedule_wrap(function()
          if not vim.api.nvim_win_is_valid(self.winid) then
            return
          end
          local blending = vim.api.nvim_get_option_value('winblend', { win = self.winid }) + self.decay
          if blending > 100 then
            blending = 100
          end
          vim.api.nvim_set_option_value('winblend', blending, { win = self.winid })
          if vim.api.nvim_get_option_value('winblend', { win = self.winid }) == 100 and self.timer:is_active() then
            self.timer:stop()
            self.is_running = false
            vim.api.nvim_win_close(self.winid, true)
          end
        end)
      )
    end)
  else
    vim.api.nvim_win_set_config(self.winid, region)
    vim.api.nvim_set_option_value('winblend', self.blend, { win = self.winid })
  end
end

return M
