---@class Rereope
local rereope = {}
local Instance = {}

local PLUGIN_NAME = 'rereope.nvim'
local OPERATOR_FUNC = "v:lua.require'rereope'.operator"
local VISUAL_BG = 'RereopeVisualFlash'
local HLGROUP = { BG = 'RereopeHintBg', BORDER = 'RereopeHintBorder' }

local ns = vim.api.nvim_create_namespace(PLUGIN_NAME)
local augroup = vim.api.nvim_create_augroup(PLUGIN_NAME, { clear = true })

---@type true?
local hl_loaded

local function set_operatorfunc()
  vim.o.operatorfunc = OPERATOR_FUNC
  vim.api.nvim_create_autocmd({ 'OptionSet' }, {
    group = augroup,
    pattern = 'operatorfunc',
    once = true,
    callback = function(_)
      if vim.v.option_new ~= OPERATOR_FUNC then
        Instance = {}
      end
    end,
  })
end

local function set_hint_hl()
  local normal = vim.fn.hlexists(HLGROUP.BG) == 1 and HLGROUP.BG or 'PmenuSel'
  local border = vim.fn.hlexists(HLGROUP.BORDER) == 1 and HLGROUP.BORDER or 'PmenuSel'
  vim.api.nvim_set_hl(ns, 'NormalFloat', { link = normal })
  vim.api.nvim_set_hl(ns, 'FloatBorder', { link = border })
end

---@param hlgroup string
local function set_visual_bg(hlgroup)
  if not hl_loaded or not vim.fn.hlexists(hlgroup) then
    hl_loaded = true
    local rgb = vim.api.nvim_get_hl(0, { name = hlgroup, create = false })
    local base_bg = rgb.reverse and rgb.fg or rgb.bg
    if base_bg then
      local ok, bg = require('rereope.highlight').fade_color(base_bg, 50)
      if ok then
        vim.api.nvim_set_hl(0, VISUAL_BG, { default = true, bg = bg })
      end
    end
  end
end

vim.api.nvim_create_autocmd({ 'ColorScheme' }, {
  desc = 'Rereope reset highlight flag',
  group = augroup,
  callback = function(_)
    hl_loaded = nil
    set_hint_hl()
  end,
})

function rereope.new(regname, opts)
  ---@class Rereope
  local self = setmetatable({}, { __index = rereope })
  opts = opts or {}
  opts.hint = opts.hint or {}
  self['bufnr'] = vim.api.nvim_get_current_buf()
  self['winid'] = vim.api.nvim_get_current_win()
  self['mode'] = vim.api.nvim_get_mode().mode
  self['selection'] = vim.go.selection
  self['clipboard'] = vim.go.clipboard
  self['virtualedit'] = vim.wo[self.winid].virtualedit
  self['regname'] = regname
  self['reginfo'] = vim.fn.getreginfo(self.regname)
  self['end_point'] = opts.end_point
  self['hint_options'] = opts.hint
  self['beacon'] = type(opts.beacon) == 'table' and require('rereope.beacon').new(unpack(opts.beacon))
  self['replace'] = opts.replace
  self['motion'] = opts.motion
  return self
end

function rereope.initial_related_options(self)
  vim.o.clipboard = nil
  vim.o.selection = 'inclusive'
  vim.wo[self.winid].virtualedit = nil
end

function rereope.restore_related_options(self)
  vim.o.clipboard = self.clipboard
  vim.o.selection = self.selection
  vim.wo[self.winid].virtualedit = self.virtualedit
end

function rereope.replace_regcontents(self)
  if self.replace and type(self.replace.fallback) == 'function' then
    if not self.replace.mode or self.mode:find(self.replace.mode, 1, true) then
      if not self.replace.regtype or self.reginfo.regtype:find(self.replace.regtype, 1, true) then
        if not self.replace.regname or self.replace.regname == self.regname then
          local iter = vim.iter(self.reginfo.regcontents):map(function(line)
            return self.replace.fallback(line)
          end)
          self.reginfo.regcontents = iter:totable()
        end
      end
    end
  end
end

function rereope.popup_hint(self)
  if vim.fn.reg_executing() == '' and not self.mode:find('[vV\x16]') then
    vim.schedule(function()
      local float_win = require('rereope.render').infotip(ns, self.reginfo.regcontents, self.hint_options)
      vim.api.nvim_create_autocmd({ 'ModeChanged' }, {
        group = augroup,
        pattern = 'no:[nc]*',
        once = true,
        callback = function(_)
          if float_win and vim.api.nvim_buf_is_valid(float_win[1]) then
            vim.api.nvim_buf_delete(float_win[1], { force = true })
          end
        end,
      })
    end)
  end
end

---@param regtype string
---@return boolean
local function is_blockwise(regtype)
  return regtype:find('\x16', 1, true) ~= nil
end

-- Adjust the number for 0-based
---@param func_name string vim-function
---@param expr string|{[1]:integer,[2]:string} Special charcactor
---@return integer zero-based index
local function zero_based(func_name, expr)
  return vim.fn[func_name](expr) - 1
end

-- Returns the selection range in Range4 format
---@param from string
---@param to string
---@param inclusive boolean Whether to include the last character in the range
---@return integer,integer,integer,integer `Range4`
local function extract_region(from, to, inclusive)
  ---@type integer,integer,integer,integer
  local start_row, start_col, end_row, end_col
  local last = inclusive and 0 or 1
  start_row, start_col = vim.fn.line(from), vim.fn.col(from)
  end_row, end_col = vim.fn.line(to), vim.fn.col(to) + last
  local max_col = vim.fn.col({ end_row, '$' }) - 1
  return start_row - 1, start_col - 1, end_row - 1, math.min(max_col, end_col)
end

function rereope:substitution(start_row, start_col, end_row, end_col)
  local reginfo = self.reginfo
  local line_count = #reginfo.regcontents
  if is_blockwise(reginfo.regtype) then
    if start_row == end_row then
      for i = 0, line_count - 1 do
        local row = start_row + i
        if vim.fn.col({ row + 1, '$' }) > end_col then
          vim.api.nvim_buf_set_text(self.bufnr, row, start_col, row, end_col, { '' })
        end
      end
      vim.api.nvim_put(reginfo.regcontents, 'b', false, false)
      return true
    else
      vim.notify(
        'The content of blockwise registers does not support pasting in visual-mode.',
        vim.log.levels.INFO,
        { title = PLUGIN_NAME }
      )
      return false
    end
  elseif is_blockwise(self.mode) then
    local row_range = end_row - start_row
    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(self.winid))
    local diff_row = (cur_row - 1) - start_row
    local diff_col = cur_col - start_col
    local row
    for i = 0, row_range do
      row = start_row + i + diff_row
      if vim.fn.col({ row + 1, '$' }) > (end_col + diff_col) then
        vim.api.nvim_buf_set_text(
          self.bufnr,
          row,
          start_col + diff_col,
          row,
          end_col + diff_col,
          { reginfo.regcontents[i + 1] }
        )
      end
    end
    end_row = row + 1
    end_col = start_col + #reginfo.regcontents[line_count] - 1
    vim.api.nvim_buf_set_mark(self.bufnr, ']', end_row, end_col, {})
    return true
  end
  vim.api.nvim_buf_set_text(self.bufnr, start_row, start_col, end_row, end_col, reginfo.regcontents)
  end_row = start_row + line_count
  end_col = start_col + #reginfo.regcontents[line_count] - 1
  vim.api.nvim_buf_set_mark(self.bufnr, ']', end_row, end_col, {})
  return true
end

function rereope:increase_reginfo()
  local new_number = tonumber(self.regname) + 1
  self.regname = tostring(math.min(9, new_number))
  self.reginfo = vim.fn.getreginfo(self.regname)
end

local function adjust_end_col(end_row, end_col)
  if end_col > 1 then
    end_col = end_col - 1
    local line = vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1]
    local charwidth = #vim.fn.strcharpart(line, end_col, 1)
    end_col = end_col + charwidth
  end
  return end_col
end

function rereope.operator(motionwise)
  Instance:initial_related_options()
  if Instance.is_repeat and Instance.regname:match('^[1-9]$') then
    Instance:increase_reginfo()
    Instance:replace_regcontents()
  end
  if Instance.regname == '=' then
    ---@diagnostic disable-next-line: redundant-parameter
    Instance.reginfo.regcontents = vim.fn.getreg('=', 0, true)
    Instance:replace_regcontents()
  end

  ---@type integer,integer,integer,integer
  local start_row, start_col, end_row, end_col
  Instance.motionwise = motionwise
  if Instance.mode:find('vV') then
    start_row, start_col, end_row, end_col = extract_region("'<", "'>", true)
  else
    start_row, start_col, end_row, end_col = extract_region("'[", "']", true)
    if motionwise == 'line' and start_row == end_row then
      start_col = 0
      end_col = zero_based('col', '$')
    end
  end
  end_col = adjust_end_col(end_row, end_col)

  if (start_row > end_row) or (start_row == end_row and start_col > end_col) then
    -- print('[rereope.nvim] debug: error range')
    return
  end

  local success = Instance:substitution(start_row, start_col, end_row, end_col)
  if not success then
    return
  end

  local move_cursor = Instance.end_point and '`]' or '`['
  vim.api.nvim_input(move_cursor)

  if Instance.beacon then
    local winheight = #Instance.reginfo.regcontents
    if Instance.reginfo.regtype:find('\x16', 1, true) or (Instance.mode == 'n' and winheight == 1) then
      Instance.beacon:replaced_region(Instance.reginfo.regcontents[1], winheight, Instance.end_point)
    else
      set_visual_bg(Instance.beacon.hlgroup)
      vim.hl.on_yank({
        event = { operator = 'y', regtype = 'v' },
        on_visual = true,
        higroup = VISUAL_BG,
        timeout = 200,
      })
    end
  end

  Instance:restore_related_options()
  Instance.is_repeat = true
end

-- Display the expression input bar and set the obtained expression in the register
---@return boolean
local function set_expression()
  local ok = false
  vim.ui.input({ prompt = '=', default = vim.fn.getreg('=', 1), completion = 'expression' }, function(input)
    if input then
      ok = true
      vim.fn.setreg('=', input)
    end
  end)
  return ok
end

function rereope.open(alterkey, opts)
  if vim.bo.readonly or not vim.bo.modifiable then
    vim.notify('Could not replace. Write protected.', vim.log.levels.INFO, { title = PLUGIN_NAME })
    return
  end
  local rgx = '["%-%w:%.%%#%*%+~=_/]'
  local register = vim.v.register
  if register == '"' then
    register = vim.fn.nr2char(vim.fn.getchar())
    alterkey = alterkey or '\\'
    if register == alterkey then
      register = '"'
    end
  end
  if register ~= '' and register:find(rgx) then
    if register == '=' then
      local ok = set_expression()
      if not ok then
        return
      end
    end
    Instance = rereope.new(register, opts)
    if not vim.tbl_isempty(Instance.reginfo) then
      if Instance.regname ~= '=' and type(Instance.replace) == 'table' then
        Instance:replace_regcontents()
      end
      if not vim.tbl_isempty(Instance.hint_options) then
        Instance:popup_hint()
      end
      set_operatorfunc()
      vim.api.nvim_feedkeys('g@', 'n', false)
      if type(Instance.motion) == 'function' then
        vim.schedule(function()
          Instance.motion()
        end)
      end
    end
  end
end

function rereope.setup()
  set_hint_hl()
end

return rereope
