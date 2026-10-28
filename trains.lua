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

---Determine if given entity is a valid stop connected to rail.
---@param stop LuaEntity?
---@return boolean
function lib.is_rail_connected_stop(stop)
	if
		stop
		and stop.valid
		and stop.type == "train-stop"
		and stop.connected_rail
	then
		return true
	else
		return false
	end
end

local RD_FRONT = defines.rail_direction.front
local RD_BACK = defines.rail_direction.back

---@param direction defines.rail_direction
---@return defines.rail_direction
local function get_opposite_rail_direction(direction)
	if direction == RD_FRONT then
		return RD_BACK
	elseif direction == RD_BACK then
		return RD_FRONT
	end
	return direction
end
lib.get_opposite_rail_direction = get_opposite_rail_direction

---Generates both forward and reverse start entries for a path query starting at the given stop.
---@param stop LuaEntity?
---@return (RailEndStart[])?
function lib.generate_path_query_starts(stop)
	if not stop then return end
	local rail = stop.connected_rail
	if not rail then return end
	local crd = stop.connected_rail_direction
	---@type RailEndStart[]
	local starts = {
		{ rail = rail, direction = crd, is_front = true },
		{
			rail = rail,
			direction = get_opposite_rail_direction(crd),
			is_front = false,
		},
	}
	return starts
end

return lib
