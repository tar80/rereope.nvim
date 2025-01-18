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
