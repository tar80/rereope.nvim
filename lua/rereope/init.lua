---@class Rereope
local Rereope = {}
---@type Instance|{}
local Instance = {}

local UNIQUE_NAME = 'rereope.nvim'
local OPERATOR_FUNC = "v:lua.require'rereope'.operator"
local HLGROUP = { BG = 'RereopeHintBg', BORDER = 'RereopeHintBorder', VISUAL_BG = 'RereopeVisualFlash' }

local ns = vim.api.nvim_create_namespace(UNIQUE_NAME)
local augroup = vim.api.nvim_create_augroup(UNIQUE_NAME, { clear = true })
local with_unique_name = require('rereope.util').name_formatter(UNIQUE_NAME)

---@type true?
local hl_loaded

local function set_operatorfunc()
  vim.o.operatorfunc = OPERATOR_FUNC
  vim.api.nvim_create_autocmd({ 'OptionSet' }, {
    desc = with_unique_name('%s: reset instance'),
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

---@param regname string|integer
---@return true?
local function match_number_register(regname)
  return ('0123456789'):find(regname, 1, true) and true
end

---@param increase boolean
---@param key {next:string,prev:string}
---@return string
local function change_register(increase, key)
  if vim.tbl_isempty(Instance) then
    return increase and key.next or key.prev
  end
  if match_number_register(Instance.regname) then
    local regname ---@type integer|string
    if increase then
      regname = Instance.regname + 1
      if regname > 9 then
        regname = match_number_register(Instance.held_regname) and 0 or Instance.held_regname
      end
    else
      regname = Instance.regname - 1
      if regname < 0 then
        regname = match_number_register(Instance.held_regname) and 9 or Instance.held_regname
      end
    end
    Instance.regname = tostring(regname)
  else
    Instance.regname = increase and '0' or '9'
  end
  Instance.reginfo.regcontents = vim.fn.getreg(Instance.regname, 0, true) --[=[@as string[]]=]
  Rereope:replace_regcontents()
  if not vim.tbl_isempty(Instance.hint_options) then
    vim.schedule(function()
      require('rereope.render').infotip_overwrite(Instance.float[1], Instance.float[2], Instance.reginfo.regcontents)
    end)
  end
  return ''
end

local function set_keymap(keys)
  local key = { next = keys.next or '<C-n>', prev = keys.prev or '<C-p>' }
  vim.keymap.set('o', key.next, function()
    return change_register(true, key)
  end, { noremap = true, expr = true, desc = with_unique_name('[%s] increase the register number') })
  vim.keymap.set('o', key.prev, function()
    return change_register(false, key)
  end, { noremap = true, expr = true, desc = with_unique_name('[%s] reduce the register number') })
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
        vim.api.nvim_set_hl(0, HLGROUP.VISUAL_BG, { default = true, bg = bg })
      end
    end
  end
end

vim.api.nvim_create_autocmd({ 'ColorScheme' }, {
  desc = with_unique_name('%s: reset highlights'),
  group = augroup,
  callback = function(_)
    hl_loaded = nil
    set_hint_hl()
  end,
})

function Rereope:new(regname, opts)
  opts = opts or {}
  opts.hint = opts.hint or {}
  local instance = {}
  instance['bufnr'] = vim.api.nvim_get_current_buf()
  instance['winid'] = vim.api.nvim_get_current_win()
  instance['mode'] = vim.api.nvim_get_mode().mode
  instance['selection'] = vim.go.selection
  instance['clipboard'] = vim.go.clipboard
  instance['virtualedit'] = vim.wo[instance.winid].virtualedit
  instance['held_regname'] = regname
  instance['regname'] = regname
  instance['reginfo'] = vim.fn.getreginfo(instance.regname)
  instance['end_point'] = opts.end_point
  instance['hint_options'] = opts.hint
  instance['beacon'] = type(opts.beacon) == 'table' and require('rereope.beacon').new(unpack(opts.beacon))
  instance['motion'] = opts.motion
  instance['replace'] = opts.replace
  return instance
end

function Rereope:initial_related_options()
  vim.o.clipboard = nil
  vim.o.selection = 'inclusive'
  vim.wo[Instance.winid].virtualedit = nil
end

function Rereope:restore_related_options()
  vim.o.clipboard = Instance.clipboard
  vim.o.selection = Instance.selection
  vim.wo[Instance.winid].virtualedit = Instance.virtualedit
end

function Rereope:replace_regcontents()
  if Instance.replace and type(Instance.replace.fallback) == 'function' then
    if not Instance.replace.mode or Instance.mode:find(Instance.replace.mode, 1, true) then
      if not Instance.replace.regtype or Instance.reginfo.regtype:find(Instance.replace.regtype, 1, true) then
        if not Instance.replace.regname or Instance.replace.regname == Instance.regname then
          local iter = vim.iter(Instance.reginfo.regcontents):map(function(line)
            return Instance.replace.fallback(line)
          end)
          Instance.reginfo.regcontents = iter:totable()
        end
      end
    end
  end
end

function Rereope:popup_hint()
  if vim.fn.reg_executing() == '' and not Instance.mode:find('[vV\x16]') then
    vim.schedule(function()
      local float_win = require('rereope.render').infotip(ns, Instance.reginfo.regcontents, Instance.hint_options)
      Instance.float = float_win
      vim.api.nvim_create_autocmd({ 'ModeChanged' }, {
        desc = with_unique_name('%s: close hint window'),
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
  local line = vim.api.nvim_get_current_line()
  if #line > 0 then
    end_col = end_col + vim.str_utf_end(line, end_col)
  end
  return start_row - 1, start_col - 1, end_row - 1, math.min(max_col, end_col)
end

function Rereope:substitution(start_row, start_col, end_row, end_col)
  local reginfo = Instance.reginfo
  local line_count = #reginfo.regcontents
  if is_blockwise(reginfo.regtype) then
    if start_row == end_row then
      for i = 0, line_count - 1 do
        local row = start_row + i
        if vim.fn.col({ row + 1, '$' }) > end_col then
          vim.api.nvim_buf_set_text(Instance.bufnr, row, start_col, row, end_col, { '' })
        end
      end
      vim.api.nvim_put(reginfo.regcontents, 'b', false, false)
      return true
    else
      vim.notify(
        'The content of blockwise registers does not support pasting in visual-mode.',
        vim.log.levels.INFO,
        { title = UNIQUE_NAME }
      )
      return false
    end
  elseif is_blockwise(Instance.mode) then
    local row_range = end_row - start_row
    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(Instance.winid))
    local diff_row = (cur_row - 1) - start_row
    local diff_col = cur_col - start_col
    local row
    for i = 0, row_range do
      row = start_row + i + diff_row
      if vim.fn.col({ row + 1, '$' }) > (end_col + diff_col) then
        vim.api.nvim_buf_set_text(
          Instance.bufnr,
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
    vim.api.nvim_buf_set_mark(Instance.bufnr, ']', end_row, end_col, {})
    return true
  end
  vim.api.nvim_buf_set_text(Instance.bufnr, start_row, start_col, end_row, end_col, reginfo.regcontents)
  end_row = start_row + line_count
  end_col = start_col + #reginfo.regcontents[line_count] - 1
  vim.api.nvim_buf_set_mark(Instance.bufnr, ']', end_row, end_col, {})
  return true
end

function Rereope:increase_reginfo()
  local new_number = tonumber(Instance.regname) + 1
  if new_number > 9 then
    new_number = 1
  end
  Instance.regname = tostring(new_number)
  Instance.reginfo = vim.fn.getreginfo(Instance.regname)
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

return {
  open = function(alterkey, opts)
    if vim.bo.readonly or not vim.bo.modifiable then
      vim.notify('Could not replace. Write protected.', vim.log.levels.INFO, { title = UNIQUE_NAME })
      return
    end
    local rgx = '["%-%w:%.%%#%*%+~=_/]'
    local register = vim.v.register
    if register == '"' then
      register = vim.fn.nr2char(vim.fn.getchar() --[[@as integer]])
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
      Instance = Rereope:new(register, opts)
      if not vim.tbl_isempty(Instance.reginfo) then
        if Instance.regname ~= '=' and type(Instance.replace) == 'table' then
          Rereope:replace_regcontents()
        end
        if not vim.tbl_isempty(Instance.hint_options) then
          Rereope:popup_hint()
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
  end,

  operator = function(motionwise)
    Rereope:initial_related_options()
    if Instance.is_repeat and match_number_register(Instance.regname) then
      Rereope:increase_reginfo()
      Rereope:replace_regcontents()
    end
    if Instance.regname == '=' then
      ---@diagnostic disable-next-line: redundant-parameter
      Instance.reginfo.regcontents = vim.fn.getreg('=', 0, true) --[=[@as string[]]=]
      Rereope:replace_regcontents()
    end

    ---@type integer,integer,integer,integer
    local start_row, start_col, end_row, end_col
    Rereope.motionwise = motionwise
    if Instance.mode:find('vV') then
      start_row, start_col, end_row, end_col = extract_region("'<", "'>", true)
    else
      start_row, start_col, end_row, end_col = extract_region("'[", "']", true)
      if motionwise == 'line' and start_row == end_row then
        start_col = 0
        end_col = zero_based('col', '$')
      end
    end

    if (start_row > end_row) or (start_row == end_row and start_col > end_col) then
      -- print('[rereope.nvim] debug: error range')
      return
    end

    local success = Rereope:substitution(start_row, start_col, end_row, end_col)
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
          higroup = HLGROUP.VISUAL_BG,
          timeout = 200,
        })
      end
    end

    Rereope:restore_related_options()
    Instance.is_repeat = true
  end,

  setup = function(opts)
    set_hint_hl()
    if opts.map_cyclic_register_keys then
      vim.validate('map_cyclic_register_keys', opts.map_cyclic_register_keys, { 'table', 'table' }, false)
      set_keymap(opts.map_cyclic_register_keys)
    end
  end,
}
