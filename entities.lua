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

---@param ghost LuaEntity A *valid* `entity-ghost`
---@param key string
---@param value Tags|boolean|number|string
function lib.ghost_set_tag(ghost, key, value)
	local tags = ghost.tags or {}
	tags[key] = value
	ghost.tags = tags
end

return lib
