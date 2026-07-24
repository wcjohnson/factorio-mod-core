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
local function create_era_counter(x0, alpha)
	return { x0 or 0, alpha or DEFAULT_ALPHA, x0 or 0, x0 or 0 }
end
lib.create_era_counter = create_era_counter

---@param counter Core.EraCounter
---@param x number New value to incorporate into the counter
---@return number
local function update_era_counter(counter, x)
	if counter == nil then return 0 end
	local alpha = counter[2] or DEFAULT_ALPHA
	local next = alpha * x + (1 - alpha) * counter[1]
	counter[1] = next
	counter[3] = min(counter[3], x)
	counter[4] = max(counter[4], x)
	return next
end
lib.update_era_counter = update_era_counter

---Create or update an era counter in a table.
---If the counter does not exist, it is created with the given value and alpha.
---@param container table Table to store the counter in
---@param key any Key to store the counter under
---@param x number New value to incorporate into the counter
---@param alpha? number Alpha value for the exponential rolling average, only used if the counter is created
function lib.create_or_update_era_counter(container, key, x, alpha)
	local counter = container[key]
	if not counter then
		counter = create_era_counter(x, alpha)
		container[key] = counter
	else
		update_era_counter(counter, x)
	end
	return counter
end

return lib
