local floor = math.floor
local ceil = math.ceil
local abs = math.abs
local tostring = tostring
local strformat = string.format
local log = math.log

local lib = {}

---Maximum safe integer representable as a `number`
local MAX_SAFE_INTEGER = 9007199254740991
lib.MAX_SAFE_INTEGER = MAX_SAFE_INTEGER

---A large integer slightly below the maximum safe integer in Lua.
local BIG_INT = 9007199254740000
lib.BIG_INT = BIG_INT

local INT32_MAX = 2147483648
lib.INT32_MAX = INT32_MAX
local INT32_MIN = -2147483647
lib.INT32_MIN = INT32_MIN

local UINT32_MAX = 4294967295
lib.UINT32_MAX = UINT32_MAX

local UINT32_MAX_PLUS_ONE = 4294967296

---Convert a uint32 to a signed int32. This is a "bit-for-bit" conversion, so the resulting int32 will have the same binary representation as the original uint32.
---@param x uint32
---@return int32
function lib.uint32_to_int32(x)
	if x > INT32_MAX then
		return x - UINT32_MAX_PLUS_ONE
	else
		return x
	end
end

---Round to nearest factor of `bracket`.
---@param v number The value to round.
---@param bracket? number The rounding bracket. Defaults to 1.
local function round(v, bracket)
	bracket = bracket or 1
	local sign = (v >= 0 and 1) or -1
	return floor(v / bracket + 0.5) * bracket
end
lib.round = round

---Clamped log for measuring algorithm runtimes. Ensures that small inputs do not produce degenerate outputs. Always returns 1 when `n <= 1`
---@param n number The number to take the logarithm of.
---@param base number? The base of the logarithm. Defaults to `math.e`.
function lib.clamped_log(n, base)
	if n <= 1 then return 1 end
	return log(n, base)
end

---Format a number of ticks in the form "HHvhMMvmSSvs" where a second is
---60 ticks.
---@param ticks number The number of ticks.
function lib.format_ticks(ticks)
	ticks = abs(ticks)
	local seconds = floor(ticks / 60)
	local minutes = floor(seconds / 60)
	local hours = floor(minutes / 60)
	seconds = seconds % 60
	minutes = minutes % 60
	if minutes == 0 and hours == 0 then
		return string.format("%ds", seconds)
	elseif hours == 0 then
		return string.format("%dm%02ds", minutes, seconds)
	else
		return string.format("%dh%02dm%02ds", hours, minutes, seconds)
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

---Clamp a numeric value between min and max.
---@param value number? The value to clamp.
---@param min number The minimum value.
---@param max number The maximum value.
---@param default number The default value if nil.
---@return number clamped The clamped value.
function lib.clamp(value, min, max, default)
	value = value or default
	if value < min then
		return min
	elseif value > max then
		return max
	else
		return value
	end
end

---If a number is very close to an integer, return that integer. Else return
---the floor.
---@param x number The number to floor.
---@return integer floored The floored value.
local function floor_approx(x)
	local top = ceil(x)
	if abs(top - x) < 0.001 then
		return top
	else
		return floor(x)
	end
end
lib.floor_approx = floor_approx

---If a number is very close to an integer, return that integer. Else return
---the ceil.
---@param x number The number to ceil.
---@return number ceiled The ceiled value.
function lib.ceil_approx(x)
	local bot = floor(x)
	if abs(bot - x) < 0.001 then
		return bot
	else
		return ceil(x)
	end
end

--- Round floorwards to the nearest Factorio tile.
function lib.floor_tile(x) return floor_approx(x - 0.5) end

---Explicit boolean conversion.
---@param x any
---@return boolean
function lib.Boolean(x)
	if x then
		return true
	else
		return false
	end
end

---Round towards zero.
---@param value number The value to truncate.
local function truncate(value) return value >= 0 and floor(value) or ceil(value) end
lib.truncate = truncate

---Format an int32 signal count into a SI-suffixed string that fits in an elem
---button.
---@param count int32 The signal count to format.
function lib.format_signal_count(count)
	local magnitude = abs(count)
	local divisor, suffix

	if magnitude >= 1e9 then
		divisor, suffix = 1e9, "G"
	elseif magnitude >= 1e6 then
		divisor, suffix = 1e6, "M"
	elseif magnitude >= 1e3 then
		divisor, suffix = 1e3, "k"
	else
		return tostring(count)
	end

	local scaled = count / divisor
	if magnitude >= divisor * 10 then return truncate(scaled) .. suffix end
	return strformat("%.1f%s", truncate(scaled * 10) / 10, suffix)
end

return lib
