local M = {}

---@param int integer
---@return string hex
local function num_to_hex(int)
  local hex = string.format('%X', int)
  local len = #hex
  if len <= 6 then
    hex = string.rep('0', 6 - len) .. hex
  end
  return '#' .. hex
end

---@param value string|number
---@return boolean ok, string hex
local function value_to_hex(value)
  local value_type = type(value)
  if value_type == 'number' then
    value = num_to_hex(value)
  end
  if value:len() ~= 7 or not value:lower():match('^#[1234567890abcdef]*$') then
    return false, ''
  end

  return true, value
end

---Simple RGB color fader
---@param rgb string|integer
---@param attenuation number
---@return boolean ok, string RGB
function M.fade_color(rgb, attenuation)
  local ok, hex = value_to_hex(rgb)
  if not ok then
    return false, 'rgb must be color-code.'
  end
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  local b = tonumber(hex:sub(5, 6), 16)

  if attenuation < 0 or attenuation > 100 then
    return false, 'Invalid attenuation value'
  end

  attenuation = (attenuation / 100) * 255

  if vim.go.background == 'light' then
    r = math.min(255, r + attenuation * (1 - r / 255))
    g = math.min(255, g + attenuation * (1 - g / 255))
    b = math.min(255, b + attenuation * (1 - b / 255))
  else
    r = math.max(0, r - attenuation)
    g = math.max(0, g - attenuation)
    b = math.max(0, b - attenuation)
  end

  return true, ('#%02X%02X%02X'):format(r, g, b)
end

return M
