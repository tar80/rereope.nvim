---@diagnostic disable: missing-fields
_G._TEST = true
local assert = require('luassert')
local rereope_mod = require('rereope')
local Rereope = rereope_mod.rereope

describe('rereope', function()
  local bufnr, new_bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    new_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'hello world',
      'rereope test line',
      'neovim lua',
    })

    vim.fn.setreg('a', 'REPLACED_A')
    vim.fn.setreg('1', 'REG_1')
    vim.fn.setreg('2', 'REG_2')

    rereope_mod.instance = {}
  end)

  after_each(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe('Instance Lifecycle', function()
    it('should create a valid instance via Rereope:new', function()
      local opts = { end_point = true }
      local inst = Rereope:new('a', opts)

      assert.are.equal('a', inst.regname)
      assert.are.equal('REPLACED_A', inst.reginfo.regcontents[1])
      assert.is_true(inst.end_point)
      assert.are.equal(bufnr, inst.bufnr)
    end)
  end)

  describe('Substitution Logic', function()
    it('should replace text correctly in normal mode (characterwise)', function()
      local inst = Rereope:new('a', {})

      for k, v in pairs(inst) do
        rereope_mod.get_instance()[k] = v
      end

      local start_row, start_col = 0, 0
      local end_row, end_col = 0, 5

      Rereope:substitution(start_row, start_col, end_row, end_col)

      local line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
      assert.are.equal('REPLACED_A world', line)
    end)
  end)

  describe('Register Cycling', function()
    it('should increment register number from 1 to 2', function()
      local inst = Rereope:new('1', {})
      rereope_mod.set_instance(inst)
      Rereope:increase_reginfo()

      local current_inst = rereope_mod.get_instance()
      assert.are.equal('2', current_inst.regname)
      assert.are.equal('REG_2', current_inst.reginfo.regcontents[1])
    end)

    it('should wrap around from 9 back to 1', function()
      vim.fn.setreg('9', 'REG_9')
      vim.fn.setreg('1', 'REG_1')

      local inst = Rereope:new('9', {})
      rereope_mod.set_instance(inst)

      Rereope:increase_reginfo()

      local current_inst = rereope_mod.get_instance()
      assert.are.equal('1', current_inst.regname)
    end)
  end)

  describe('Replace Fallback', function()
    it('should apply fallback function to register contents', function()
      local opts = {
        replace = {
          fallback = function(line)
            return 'PREFIX_' .. line
          end,
        },
      }
      local inst = Rereope:new('a', opts)
      rereope_mod.set_instance(inst)
      Rereope:replace_regcontents()

      local current_inst = rereope_mod.get_instance()
      assert.are.equal('PREFIX_REPLACED_A', current_inst.reginfo.regcontents[1])
    end)
  end)

  describe('Options Management', function()
    it('should temporarily change and then restore options', function()
      local original_selection = vim.go.selection
      local inst = Rereope:new('a', {})
      rereope_mod.instance = inst

      Rereope:initial_related_options()
      assert.are.equal('inclusive', vim.o.selection)

      Rereope:restore_related_options()
      assert.are.equal(original_selection, vim.o.selection)
    end)
  end)

  describe('Multi-buffer Support', function()
    it('should successfully replace text in a different buffer (Dot-repeat behavior)', function()
      vim.api.nvim_set_current_buf(bufnr)
      local inst = Rereope:new('a', {})
      rereope_mod.set_instance(inst)

      vim.api.nvim_set_current_buf(new_bufnr)
      vim.api.nvim_buf_set_lines(new_bufnr, 0, -1, false, { 'TARGET TEXT' })
      vim.api.nvim_buf_set_mark(new_bufnr, '[', 1, 0, {})
      vim.api.nvim_buf_set_mark(new_bufnr, ']', 1, 5, {})

      rereope_mod.operator('char')
      local line_new = vim.api.nvim_buf_get_lines(new_bufnr, 0, 1, false)[1]
      assert.are.equal('REPLACED_A TEXT', line_new)

      local line_old = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
      assert.are.equal('hello world', line_old)
    end)
  end)

  describe('rereope.nvim final verification', function()
    local bufnr_a, bufnr_b

    before_each(function()
      bufnr_a = vim.api.nvim_create_buf(false, true)
      bufnr_b = vim.api.nvim_create_buf(false, true)

      vim.api.nvim_buf_set_lines(bufnr_a, 0, -1, false, { 'あいうえお', 'abcde' })
      vim.api.nvim_buf_set_lines(bufnr_b, 0, -1, false, { 'TARGET BUFFER B' })
      vim.fn.setreg('a', '置換完了')

      rereope_mod.set_instance({})
    end)

    describe('Multibyte handling', function()
      it('should correctly replace multibyte characters without breaking byte sequences', function()
        vim.api.nvim_win_set_buf(0, bufnr_a)
        local inst = Rereope:new('a', {})
        rereope_mod.set_instance(inst)

        vim.api.nvim_buf_set_mark(bufnr_a, '[', 1, 3, {}) -- 1-based, col 4 is index 3
        vim.api.nvim_buf_set_mark(bufnr_a, ']', 1, 8, {}) -- 1-based, col 9 is index 8

        rereope_mod.operator('char')

        local result = vim.api.nvim_buf_get_lines(bufnr_a, 0, 1, false)[1]
        assert.are.equal('あ置換完了えお', result)
      end)
    end)
  end)
end)
