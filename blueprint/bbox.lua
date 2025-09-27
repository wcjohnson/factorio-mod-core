--------------------------------------------------------------------------------
-- BLUEPRINT ENTITY BOUNDING BOXES
--------------------------------------------------------------------------------

local lib = {}

local pos_lib = require("lib.core.math.pos")
local bbox_lib = require("lib.core.math.bbox")
local geom_lib = require("lib.core.blueprint.custom-geometry")

local pos_get = pos_lib.pos_get
local bbox_new = bbox_lib.bbox_new
local bbox_rotate_ortho = bbox_lib.bbox_rotate_ortho
local bbox_translate = bbox_lib.bbox_translate
local bbox_union = bbox_lib.bbox_union
local bbox_round = bbox_lib.bbox_round
local floor = math.floor
local ZERO = { 0, 0 }

---Generically compute the bounding box of a blueprint entity in blueprint space.
---Works for all entities that obey the factorio docs.
---@param bp_entity BlueprintEntity
---@param eproto LuaEntityPrototype
local function default_bbox(bp_entity, eproto)
	local ebox = bbox_new(eproto.collision_box)
	local dir = bp_entity.direction or 0
	bbox_rotate_ortho(ebox, ZERO, floor(dir / 4))
	bbox_translate(ebox, 1, bp_entity.position)
	return ebox
end

---Compute bbox of a blueprint entity using custom geometry.
---@param bp_entity BlueprintEntity
---@param geom Core.DirectionalCustomEntityGeometry
local function custom_bbox(bp_entity, geom)
	local x, y = pos_get(bp_entity.position)
	return {
		{ x + geom[1], y + geom[2] },
		{ x + geom[3], y + geom[4] },
	}
end

---Compute the bounding box of a blueprint entity in blueprint space.
---@param bp_entity BlueprintEntity
---@return BoundingBox
function lib.get_blueprint_entity_bbox(bp_entity)
	local eproto = prototypes.entity[bp_entity.name]
	local geom =
		geom_lib.get_custom_geometry(eproto.type, eproto.name, bp_entity.direction)
	if geom then
		return custom_bbox(bp_entity, geom)
	else
		return default_bbox(bp_entity, eproto)
	end
end

---Get the net bounding box of an entire set of BP entities. Also locates an
---entity within the blueprint that will cause implied snapping for relative
---placement, if any.
---@param bp_entities BlueprintEntity[] A *nonempty* set of blueprint entities.
---@param entity_bounding_boxes? BoundingBox[] If provided, will be filled with the bounding boxes of each entity by index.
---@return BoundingBox bbox The bounding box of the blueprint in blueprint space
---@return uint? snap_index The index of the entity that causes implied snapping, if any.
function lib.get_blueprint_bbox(bp_entities, entity_bounding_boxes)
	local snap_index = nil

	local e1x, e1y = pos_get(bp_entities[1].position)
	---@type BoundingBox
	local bpspace_bbox = { { e1x, e1y }, { e1x, e1y } }

	for i = 1, #bp_entities do
		local bp_entity = bp_entities[i]
		local eproto = prototypes.entity[bp_entity.name]
		local geom = geom_lib.get_custom_geometry(
			eproto.type,
			eproto.name,
			bp_entity.direction
		)

		-- Detect entities which cause implied snapping of the blueprint.
		if snap_index == nil and geom and geom[5] then snap_index = i end

		-- Get bbox for entity and union it with existing bbox.
		local ebox = geom and custom_bbox(bp_entity, geom)
			or default_bbox(bp_entity, eproto)
		if entity_bounding_boxes then entity_bounding_boxes[i] = ebox end
		bbox_union(bpspace_bbox, ebox)
	end

	bbox_round(bpspace_bbox)

	return bpspace_bbox, snap_index
end

return lib
