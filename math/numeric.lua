local floor = math.floor

local lib = {}

---Round to nearest factor of `bracket`.
---@param v number The value to round.
---@param bracket? number The rounding bracket. Defaults to 1.
local function round(v, bracket)
	bracket = bracket or 1
	local sign = (v >= 0 and 1) or -1
	return floor(v / bracket + 0.5) * bracket
end
lib.round = round

return lib
