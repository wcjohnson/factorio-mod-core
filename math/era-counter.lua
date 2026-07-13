-- Exponential Rolling Average counters

local min = math.min
local max = math.max

local DEFAULT_ALPHA = 0.30

local lib = {}

---@class Core.EraCounter
---@field [1] number Current ERA value
---@field [2] number Alpha value for the exponential rolling average
---@field [3] number Min seen value
---@field [4] number Max seen value

---@param x0 number Initial value for the counter
---@param alpha? number Alpha value for the exponential rolling average
---@return Core.EraCounter
function lib.create_era_counter(x0, alpha)
	return { x0 or 0, alpha or DEFAULT_ALPHA, x0 or 0, x0 or 0 }
end

---@param counter Core.EraCounter
---@param x number New value to incorporate into the counter
---@return number
function lib.update_era_counter(counter, x)
	local alpha = counter[2] or DEFAULT_ALPHA
	local next = alpha * x + (1 - alpha) * counter[1]
	counter[1] = next
	counter[3] = min(counter[3], x)
	counter[4] = max(counter[4], x)
	return next
end

return lib
