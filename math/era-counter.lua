-- Exponential Rolling Average counters

local DEFAULT_ALPHA = 0.40

local lib = {}

---@class Core.EraCounter
---@field [1] number Current ERA value
---@field [2] number Alpha value for the exponential rolling average
---@field [3] number One-minus-alpha value for the exponential rolling average

---@return Core.EraCounter
function lib.create_era_counter(alpha, x0)
	return { x0 or 0, alpha or DEFAULT_ALPHA, 1 - (alpha or DEFAULT_ALPHA) }
end

---@return number
function lib.update_era_counter(counter, x)
	local next = counter[2] * x + counter[3] * counter[1]
	counter[1] = next
	return next
end
