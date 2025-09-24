--Manipulation of "world state" objects, which encode brief information
--about entities, specifically their prototype name and location.
--World states are useful for generating string hash keys as well as
--transitioning between pickled data (like undo-redo records) and live entities.

local position_lib = require("lib.core.math.pos")
local pos_get = position_lib.pos_get

---Brief information about an entity's prototype and location in the world.
---@class Core.WorldState
---@field public position MapPosition The position of the entity.
---@field public surface_index uint The surface index of the entity.
---@field public name string The prototype name of the entity.
---@field public key Core.WorldKey World key for this state

---String representation of a world state, suitable for use as a hash key.
---@alias Core.WorldKey string

local lib = {}

---@param pos MapPosition
---@param surface_index uint
---@param name string
local function make_key(pos, surface_index, name)
	local x, y = pos_get(pos)
	return string.format("%2.2f:%2.2f:%d:%s", x, y, surface_index, name)
end
lib.make_key = make_key

---Get the world state of an entity.
---@param entity LuaEntity A *valid* entity.
---@return Core.WorldState
function lib.get_world_state(entity)
	local pos = entity.position
	local surface_index = entity.surface_index
	local name = entity.type == "entity-ghost" and entity.ghost_name
		or entity.name
	return {
		position = pos,
		surface_index = surface_index,
		name = name,
		key = make_key(pos, surface_index, name),
	}
end

---Get the world key of an entity
---@param entity LuaEntity A *valid* entity.
---@return Core.WorldKey
function lib.get_world_key(entity)
	local prototype_name = entity.type == "entity-ghost" and entity.ghost_name
		or entity.name
	return make_key(entity.position, entity.surface_index, prototype_name)
end

---Parse a world key string back into its components.
---@param key Core.WorldKey
---@return Core.WorldState
function lib.parse_world_key(key)
	local x, y, surface_index, name =
		string.match(key, "^([^:]+):([^:]+):([^:]+):(.+)$")
	return {
		position = { x = tonumber(x), y = tonumber(y) },
		surface_index = tonumber(surface_index),
		name = name,
		key = key,
	}
end

return lib
