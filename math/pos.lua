local abs = math.abs
local sqrt = math.sqrt
local num_lib = require("lib.core.math.numeric")
local round = num_lib.round
local deg = math.deg
local atan2 = math.atan2

local dir_N = defines.direction.north
local dir_S = defines.direction.south
local dir_E = defines.direction.east
local dir_W = defines.direction.west

local lib = {}

---Get the coordinates of a position.
---@param pos MapPosition
local function pos_get(pos)
	if pos.x then
		return pos.x, pos.y
	else
		return pos[1], pos[2]
	end
end
lib.pos_get = pos_get

---Set the coordinates of a position.
---@param pos MapPosition
---@param x number
---@param y number
local function pos_set(pos, x, y)
	if pos.x then
		pos.x, pos.y = x, y
	else
		pos[1], pos[2] = x, y
	end
	return pos
end
lib.pos_set = pos_set

---Get the length of a position vector.
---@param pos MapPosition
---@return number
local function pos_len(pos)
	local x, y = pos_get(pos)
	return sqrt(x * x + y * y)
end
lib.pos_len = pos_len

---Scale a position vector.
---@param pos MapPosition
---@param factor number
---@return MapPosition pos The mutated position.
local function pos_scale(pos, factor)
	local x, y = pos_get(pos)
	return pos_set(pos, x * factor, y * factor)
end
lib.pos_scale = pos_scale

---Normalize a position vector to length 1. Mutates the given position.
---@param pos MapPosition
---@return MapPosition pos The mutated position.
local function pos_normalize(pos)
	local length = pos_len(pos)
	if length == 0 then
		return pos_set(pos, 0, 0)
	else
		local x, y = pos_get(pos)
		return pos_set(pos, x / length, y / length)
	end
end
lib.pos_normalize = pos_normalize

---Get the distance-squared between two positions.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@return number
local function pos_distsq(pos1, pos2)
	local x1, y1 = pos_get(pos1)
	local x2, y2 = pos_get(pos2)
	local dx, dy = x2 - x1, y2 - y1
	return dx * dx + dy * dy
end
lib.pos_distsq = pos_distsq

---Determine if two positions are approximately the same.
---@param pos1 MapPosition
---@param pos2 MapPosition
local function pos_close(pos1, pos2)
	local x1, y1 = pos_get(pos1)
	local x2, y2 = pos_get(pos2)
	local dx, dy = abs(x2 - x1), abs(y2 - y1)
	return dx < 0.01 and dy < 0.01
end
lib.pos_close = pos_close

---Create a new position, optionally cloning an existing one.
---@param pos_or_x? MapPosition|number
---@param y? number
---@return MapPosition #The new position.
local function pos_new(pos_or_x, y)
	if pos_or_x then
		if type(pos_or_x) == "table" then
			local x0, y0 = pos_get(pos_or_x)
			return { x0, y0 }
		else
			return { pos_or_x, y or 0 }
		end
	else
		return { 0, 0 }
	end
end
lib.pos_new = pos_new

---Sets `pos1 = pos1 + (factor * pos2)`.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@param factor number
---@return MapPosition pos1
local function pos_add(pos1, factor, pos2)
	local x1, y1 = pos_get(pos1)
	local x2, y2 = pos_get(pos2)
	return pos_set(pos1, x1 + x2 * factor, y1 + y2 * factor)
end
lib.pos_add = pos_add

---Move a position by the given amount in the given ortho direction.
---@param pos MapPosition
---@param dir defines.direction
---@param amount number
---@return MapPosition pos The original position, modified as requested.
local function pos_move_ortho(pos, dir, amount)
	local x, y = pos_get(pos)
	if dir == dir_N then
		y = y - amount
	elseif dir == dir_S then
		y = y + amount
	elseif dir == dir_E then
		x = x + amount
	elseif dir == dir_W then
		x = x - amount
	end
	return pos_set(pos, x, y)
end
lib.pos_move_ortho = pos_move_ortho

---Returns the primary orthogonal direction from `pos1` to `pos2`. This is one of the
---`defines.direction` constants.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@return defines.direction
local function dir_ortho(pos1, pos2)
	local x1, y1 = pos_get(pos1)
	local x2, y2 = pos_get(pos2)
	local dx, dy = x2 - x1, y2 - y1
	if abs(dx) > abs(dy) then
		return dx > 0 and dir_E or dir_W
	else
		return dy > 0 and dir_S or dir_N
	end
end
lib.dir_ortho = dir_ortho

---Rotate a position orthogonally (in increments of 90 degrees) counterclockwise
---around an origin. Mutates the given position.
---@param pos MapPosition
---@param origin MapPosition
---@param count int Rotate by `count * 90` degrees counterclockwise. May be negative to rotate clockwise.
---@return MapPosition pos The mutated position.
local function pos_rotate_ortho(pos, origin, count)
	local x, y = pos_get(pos)
	local ox, oy = pos_get(origin)

	-- Normalize count to be within 0 to 3
	count = (count % 4 + 4) % 4

	if count == 1 then
		-- 90 degrees counterclockwise
		return pos_set(pos, ox + (y - oy), oy - (x - ox))
	elseif count == 2 then
		-- 180 degrees counterclockwise
		return pos_set(pos, ox - (x - ox), oy - (y - oy))
	elseif count == 3 then
		-- 270 degrees counterclockwise (or 90 degrees clockwise)
		return pos_set(pos, ox - (y - oy), oy + (x - ox))
	else
		-- 0 degrees (no rotation)
		return pos
	end
end
lib.pos_rotate_ortho = pos_rotate_ortho

--- Calculate the direction of travel from the source to the target. Rounds
--- to the nearest `defines.direction` value. (h/t flib for this code)
--- @param from MapPosition
--- @param to MapPosition
--- @return defines.direction
function lib.dir_from(from, to)
	local d = deg(atan2(to.y - from.y, to.x - from.x))
	local direction = (d + 90) / 22.5
	if direction < 0 then direction = direction + 16 end

	direction = round(direction)

	return direction --[[@as defines.direction]]
end

return lib
