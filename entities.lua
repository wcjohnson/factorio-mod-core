local lib = {}

---Determine whether an entity is a ghost and resolve its true prototype
---regardless of whether it is a ghost or not.
---@param entity LuaEntity A *valid* entity.
---@return boolean is_ghost `true` if the entity is a ghost.
---@return string prototype_name The resolved prototype name of the underlying entity.
---@return string prototype_type The resolved prototype type of the underlying entity.
function lib.resolve_possible_ghost(entity)
	if entity.type == "entity-ghost" then
		return true, entity.ghost_name, entity.ghost_type
	end
	return false, entity.name, entity.type
end

---Get the true prototype name of an entity, resolving ghosts.
---@param entity LuaEntity A *valid* entity.
---@return string prototype_name The resolved prototype name of the underlying entity.
function lib.true_prototype_name(entity)
	if entity.type == "entity-ghost" then
		return entity.ghost_name
	else
		return entity.name
	end
end

---@param ghost LuaEntity A *valid* `entity-ghost`
---@param key string
---@param value Tags|boolean|number|string
function lib.ghost_set_tag(ghost, key, value)
	local tags = ghost.tags or {}
	tags[key] = value
	ghost.tags = tags
end

local RED = defines.wire_connector_id.circuit_red
local CI_RED = defines.wire_connector_id.combinator_input_red
local CO_RED = defines.wire_connector_id.combinator_output_red
local GREEN = defines.wire_connector_id.circuit_green
local CI_GREEN = defines.wire_connector_id.combinator_input_green
local CO_GREEN = defines.wire_connector_id.combinator_output_green

---Get the color of a wire from its wire_connector_id
---@param connector_id defines.wire_connector_id?
---@return boolean is_red
---@return boolean is_green
function lib.get_wire_color(connector_id)
	if not connector_id then return false, false end
	if
		connector_id == RED
		or connector_id == CI_RED
		or connector_id == CO_RED
	then
		return true, false
	end
	if
		connector_id == GREEN
		or connector_id == CI_GREEN
		or connector_id == CO_GREEN
	then
		return false, true
	end
	return false, false
end

return lib
