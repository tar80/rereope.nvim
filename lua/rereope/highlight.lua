local M = {}

---@param rgb string|integer
---@param attenuation number
---@return boolean ok, string RGB
function M.fade_color(rgb, attenuation)
  local rgb_type = type(rgb)
  if rgb_type == 'number' then
    rgb = string.format('%X', rgb)
  elseif rgb_type == 'string' then
    if #rgb > 6 then
      rgb = rgb:sub(-6)
    end
  else
    return false, ''
  end
  local r = tonumber(rgb:sub(1, 2), 16)
  local g = tonumber(rgb:sub(3, 4), 16)
  local b = tonumber(rgb:sub(5, 6), 16)

  attenuation = (attenuation / 100) * 255
  if vim.go.background == 'light' then
    r = r + attenuation * (1 - r / 255)
    g = g + attenuation * (1 - g / 255)
    b = b + attenuation * (1 - b / 255)
  else
    r = r - attenuation
    g = g - attenuation
    b = b - attenuation
  end

  r = math.max(0, r)
  g = math.max(0, g)
  b = math.max(0, b)

  return true, ('#%02X%02X%02X'):format(r, g, b)
end

return M
