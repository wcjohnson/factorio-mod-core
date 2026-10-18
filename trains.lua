--------------------------------------------------------------------------------
-- Utilities for dealing with Factorio trains and stops
--------------------------------------------------------------------------------

local lib = {}

---Get the stop in the same segment as this RailEnd.
---@param rail_end LuaRailEnd
---@return LuaEntity? stop
local function get_stop_from_rail_end(rail_end)
	local rail = rail_end.rail
	return rail.get_rail_segment_stop(rail_end.direction)
end
lib.get_stop_from_rail_end = get_stop_from_rail_end

---Get the stop this train is or was stopped at. If the train is not currently
---stopped at a station, uses the train's rail ends to determine the stop it may
---have just left.
---@param luatrain LuaTrain
---@return LuaEntity? stop
function lib.get_stop_from_train(luatrain)
	local stop = luatrain.station
	if stop then return stop end
	stop = get_stop_from_rail_end(luatrain.front_end)
	if stop then return stop end
	return get_stop_from_rail_end(luatrain.back_end)
end

local RD_FRONT = defines.rail_direction.front
local RD_BACK = defines.rail_direction.back

---@param direction defines.rail_direction
---@return defines.rail_direction
function lib.get_opposite_rail_direction(direction)
	if direction == RD_FRONT then
		return RD_BACK
	elseif direction == RD_BACK then
		return RD_FRONT
	end
	return direction
end

return lib
