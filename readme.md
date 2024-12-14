# Rereope.nvim

**Re**place with **Re**gister **Ope**rator

## Requirements

- Neovim >= 0.10.0
  <!-- - [tartare.nvim](https://github.com/tar80/tartare.nvim) **(optional)** -->
  <!--   This library module is exclusively for the plugins I created. -->
  <!--   It is not usually necessary, but it is used to optimize the loading of duplicate modules. -->

## Demo

Take a peek at these demo clips.

![rereope_standard](https://github.com/user-attachments/assets/7e3ae709-a0d8-411d-b25e-1e1112fbefac)

![rereope_blockwise](https://github.com/user-attachments/assets/47aa90af-0861-4ae5-bd9f-bc74cfd2eb9e)

![rereope_FIFO](https://github.com/user-attachments/assets/67eca0e9-1998-462b-8f3a-3138c41c745b)

![rereope_expression](https://github.com/user-attachments/assets/27fc8fe5-1652-4d84-a7f7-4750f88201e3)

![rereope_registers](https://github.com/user-attachments/assets/5f5a78e1-73c3-4976-acd9-25ca9d89598d)

![rereope_flash](https://github.com/user-attachments/assets/80904065-4183-42e5-97e5-c364f122a611)

## Usage

Rereope provides only one method `rereope.open`.

`rereope.open` first inputs the trigger key, followed by the register key.  
For example: `<trigger-key>[register-key]{motion}`.

Additionally, it is also possible to perform the operation in the original way
by inputting the register key first, followed by the trigger key.  
For example: `"[register-key]<trigger-key>{motion}`

It is also possible to set an `alternative-key` for the unnamed register.
This can be done by placing the trigger key and the alternative-key in close
proximity (or assigning them to the same key), which can lead to a reduction
in key operation effort.

```lua
---@param alternative-key string|nil
-- The specified key will be used as a alternative key for the unnamed register.
---@param options RereopeOptions
rereope.open(alternative-key, { end_point, beacon, hint, motion, replace })

---@class RereopeOptions

---@field end_point boolean
--- Move cursor to end of past range.

---@field beacon [ hlgroup:string, interval:integer, winblend:integer, decay:integer ]
---  Flash the replaced text.

---@field hint { winblend:integer, border:string[]|nil } Floating window option values
--- Popup hint select register contents.

---@field motion fun()
--- Automatically execute motion after register selection.

---@field replace {
---         mode:string|nil,
---         regname:string|nil,
---         regtype:string|nil,
---         fallback: fun(line:string):line:string
---       }
--- Format the register contents before pasting them.
--- Specifying `mode`, `regname`, and `regtype` will perform conditional judgment.
--- You can use fallbacks to process replacements line by line.
```

## Installation

- lazy.nvim

```lua
{
    'tar80/rereope.nvim',
    opts = {}, -- for requirements. rereope.nvim has no options.
    keys = {
        ...
    }
}
```

## Configurations

<details>
<summary> Standard replace </summary>

```lua
local opts = {
    end_point = true,
    beacon = {},
    hint = {},
}

-- Respects vim-operator-replace
vim.keymap.set({'n', 'x'}, '_', function()
    local opts = {}
    return require('rereope').open('_', opts)
end, {desc = 'Rereope open'})

-- Respects vim-ReplaceWithRegister
vim.keymap.set({'n', 'x'}, 'gr', function()
    local opts = {}
    return require('rereope').open('r', opts)
end, {desc = 'Rereope open'})
-- Linewise auto motion
vim.keymap.set({'n', 'x'}, 'gR', function()
    local opts = {
        motion = function()
            vim.api.nvim_input('_')
        end,
    }
    return require('rereope').open('R', opts)
end, {desc = 'Rereope open linewise'})
```
</details>

<details>
<summary> FIFO with format </summary>

```lua
local opts = {
    end_point = false,
    beacon = { 'IncSearch', 100, 0, 15 },
    hint = { winblend = 20, border = { '+', '-' } },
    replace = {
        fallback = function(line)
            return string.format('<%s>', line)
        end
    }
}
```
</details>

<details>
<summary> With Flash.nvim </summary>

```lua
local opts = {
    motion = function()
      if vim.treesitter.get_node() then
        require('flash').treesitter()
      end
    end,
}
```

However, special operations such as `Remote Actions` may not work correctly.
You can execute a Remote Actions by calling it normally as an operator
without using the motion option.
</details>

## Highlights

- `RereopeHintBg` (defalut:PmenuSel) Uses popup hint
- `RereopeHintBorder` (default:PmenuSel) Uses popup hint
- `RereopeVisualFlash` (default:opts.beacon.hlgroup or IncSearch) Uses replaced linewise contents

### Issues

- Regarding the beacon functionality, it has been replaced with a built-in feature
  due to the considerable effort required for its application to the visual-mode range.
  It is currently undecided whether we will address this functionality in the future.

- Pasting blocwise excluding spaces such as `zp` and `zP` is not supported.

### ToDo

The planned implementation has been completed. Next,

- [ ] write tests,
- [ ] fix bugs,
- [ ] write help document,

but I have other things to do, so I'll put it off.

## Acknowledgment

[vim-operator-replace](https://github.com/kana/vim-operator-replace)  
[vim-ReplaceWithRegister](https://github.com/inkarkat/vim-ReplaceWithRegister)
