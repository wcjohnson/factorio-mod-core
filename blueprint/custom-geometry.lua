-- Custom entity geometry data used in calculating blueprint bboxes and
-- snapping.

local lib = {}

---Custom empirical data for a single direction of a single entity. Entries are:
---[1] = Left offset from position to bbox edge.
---[2] = Top offset from position to bbox edge.
---[3] = Right offset from position to bbox edge.
---[4] = Bottom offset from position to bbox edge.
---[5] = 2x2 snapping: required parity of X coord of final world position (1=odd, 2=even, `nil`=don't use 2x2 snapping)
---[6] = 2x2 snapping: required parity of Y coord of final world position (1=odd, 2=even, `nil`=don't use 2x2 snapping)
---@alias Core.DirectionalCustomEntityGeometry { [1]: number, [2]: number, [3]: number, [4]: number, [5]: int|nil, [6]: int|nil }

---Snap data associated with each valid direction of an entity. Direction `0`
---MUST be provided and is used as a fallback for directions not provided.
---@alias Core.CustomEntityGeometry {[defines.direction]: Core.DirectionalCustomEntityGeometry}

---@type Core.CustomEntityGeometry
local straight_rail_table = {
	[0] = { -1, -1, 1, 1, 1, 1 },
	[2] = { -2, -2, 2, 2, 2, 2 },
	[4] = { -1, -1, 1, 1, 1, 1 },
	[6] = { -2, -2, 2, 2, 2, 2 },
	[8] = { -1, -1, 1, 1, 1, 1 },
	[10] = { -2, -2, 2, 2, 2, 2 },
	[12] = { -1, -1, 1, 1, 1, 1 },
	[14] = { -2, -2, 2, 2, 2, 2 },
}

---Treat curved-rail-a as 2x4 centered on its position. See:
---https://forums.factorio.com/viewtopic.php?p=613478#p613478
---@type Core.CustomEntityGeometry
local curved_rail_a_table = {
	[0] = { -1, -2, 1, 2, 1, 2 },
	[2] = { -1, -2, 1, 2, 1, 2 },
	[4] = { -2, -1, 2, 1, 2, 1 },
	[6] = { -2, -1, 2, 1, 2, 1 },
	[8] = { -1, -2, 1, 2, 1, 2 },
	[10] = { -1, -2, 1, 2, 1, 2 },
	[12] = { -2, -1, 2, 1, 1, 1 },
	[14] = { -2, -1, 2, 1, 2, 1 },
}

---Treat curved-rail-b as a 4x4 centered on its position.
---This is from empirical observation in-game.
---@type Core.CustomEntityGeometry
local curved_rail_b_table = {
	[0] = { -2, -2, 2, 2, 1, 1 },
	[2] = { -2, -2, 2, 2, 1, 1 },
	[4] = { -2, -2, 2, 2, 1, 1 },
	[6] = { -2, -2, 2, 2, 1, 1 },
	[8] = { -2, -2, 2, 2, 1, 1 },
	[10] = { -2, -2, 2, 2, 1, 1 },
	[12] = { -2, -2, 2, 2, 1, 1 },
	[14] = { -2, -2, 2, 2, 1, 1 },
}

---@type Core.CustomEntityGeometry
local half_diagonal_rail_table = {
	[0] = { -2, -2, 2, 2, 1, 1 },
	[2] = { -2, -2, 2, 2, 1, 1 },
	[4] = { -2, -2, 2, 2, 1, 1 },
	[6] = { -2, -2, 2, 2, 1, 1 },
	[8] = { -2, -2, 2, 2, 1, 1 },
	[10] = { -2, -2, 2, 2, 1, 1 },
	[12] = { -2, -2, 2, 2, 1, 1 },
	[14] = { -2, -2, 2, 2, 1, 1 },
}

---@type {[string]: Core.CustomEntityGeometry}
local custom_geometry_by_type = {
	["straight-rail"] = straight_rail_table,
	["curved-rail-a"] = curved_rail_a_table,
	["curved-rail-b"] = curved_rail_b_table,
	["half-diagonal-rail"] = half_diagonal_rail_table,
	["elevated-straight-rail"] = straight_rail_table,
	["elevated-curved-rail-a"] = curved_rail_a_table,
	["elevated-curved-rail-b"] = curved_rail_b_table,
	["elevated-half-diagonal-rail"] = half_diagonal_rail_table,
	["train-stop"] = {
		[0] = { -1, -1, 1, 1, 1, 1 },
		[4] = { -1, -1, 1, 1, 1, 1 },
		[8] = { -1, -1, 1, 1, 1, 1 },
		[12] = { -1, -1, 1, 1, 1, 1 },
	},
}

---@type {[string]: Core.CustomEntityGeometry}
local custom_geometry_by_name = {}

---Determine if an entity type/name has custom geometry defined, and if so,
---return it for the given direction.
---@param prototype_type string
---@param prototype_name string
---@param direction? defines.direction
---@return Core.DirectionalCustomEntityGeometry? geometry The custom geometry for the given entity type/name and direction, or nil if none is defined.
function lib.get_custom_geometry(prototype_type, prototype_name, direction)
	local geometry = custom_geometry_by_type[prototype_type or ""]
	if not geometry then
		geometry = custom_geometry_by_name[prototype_name or ""]
		if not geometry then return end
	end
	return geometry[direction or 0] or geometry[0]
end

---Set custom geometry for all entities of a given type.
---@param prototype_type string
---@param geometry_table Core.CustomEntityGeometry
function lib.set_custom_geometry_for_type(prototype_type, geometry_table)
	custom_geometry_by_type[prototype_type] = geometry_table
end

---Set custom geometry for a specific entity by name.
---@param prototype_name string
---@param geometry_table Core.CustomEntityGeometry
function lib.set_custom_geometry_for_name(prototype_name, geometry_table)
	custom_geometry_by_name[prototype_name] = geometry_table
end

-- TODO: allow mod registration of custom geometry.

return lib
