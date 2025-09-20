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
  if attenuation < 0 or attenuation > 100 then
    return false, 'Invalid attenuation value'
  end

  local ok, hex = value_to_hex(rgb)
  if not ok then
    return false, 'rgb must be color-code.'
  end

  local r = tonumber(hex:sub(2, 3), 16)
  local g = tonumber(hex:sub(4, 5), 16)
  local b = tonumber(hex:sub(6, 7), 16)

  attenuation = attenuation / 100

  if vim.go.background == 'light' then
    r = math.min(255, r + attenuation * (255 - r))
    g = math.min(255, g + attenuation * (255 - g))
    b = math.min(255, b + attenuation * (255 - b))
  else
    r = math.max(0, r - attenuation * r)
    g = math.max(0, g - attenuation * g)
    b = math.max(0, b - attenuation * b)
  end

  return true, ('#%02X%02X%02X'):format(r, g, b)
end

return M
