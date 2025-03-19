---@class util
local M = {}

-- Returns a closure for formatting a message with a given "name".
---@param name string The "name" to be used in the message formatting.
---@return function - A closure that takes a "message" string and returns the formatted message with "name".
function M.name_formatter(name)
  return function(message)
    return (message):format(name)
  end
end

return M
