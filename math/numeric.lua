local floor = math.floor
local strformat = string.format

local lib = {}

---Round to nearest factor of `divisor`.
---@param v number The value to round.
---@param divisor? number The rounding bracket. Defaults to 1.
local function round(v, divisor)
	divisor = divisor or 1
	if v >= 0 then
		return floor(v / divisor + 0.5) * divisor
	else
		return floor(v / divisor - 0.5) * divisor
	end
end
lib.round = round

---Format a number of ticks in the form "HHvhMMvmSSvs" where a second is
---60 ticks.
---@param ticks uint The number of ticks.
function lib.format_ticks(ticks)
	local seconds = floor(ticks / 60)
	local minutes = floor(seconds / 60)
	local hours = floor(minutes / 60)
	seconds = seconds % 60
	minutes = minutes % 60
	if minutes == 0 and hours == 0 then
		return strformat("%dvs", seconds)
	elseif hours == 0 then
		return strformat("%dvm%02dvs", minutes, seconds)
	else
		return strformat("%dvh%02dvm%02dvs", hours, minutes, seconds)
	end
end

---Format a tick as T+ or T- relative to a given T.
---@param ticks uint The number of ticks.
---@param reference uint The reference tick.
function lib.format_tick_relative(ticks, reference)
	if ticks >= reference then
		return "T+" .. lib.format_ticks(ticks - reference)
	elseif ticks < reference then
		return "T-" .. lib.format_ticks(reference - ticks)
	end
end

return lib
