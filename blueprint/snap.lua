--------------------------------------------------------------------------------
-- SNAPPING
-- Compute how blueprints snap.
--------------------------------------------------------------------------------
local bbox_lib = require("lib.core.math.bbox")
local pos_lib = require("lib.core.math.pos")
local geom_lib = require("lib.core.blueprint.custom-geometry")
local num_lib = require("lib.core.math.numeric")
local strace = require("lib.core.strace")

local lib = {}

local floor = math.floor
local bbox_get = bbox_lib.bbox_get
local pos_new = pos_lib.pos_new
local pos_add = pos_lib.pos_add
local round = num_lib.round

---Possible types of cursor snapping during relative blueprint placement.
---@enum Core.SnapType
local SnapType = {
	"GRID_POINT",
	"TILE",
	"EVEN_GRID_POINT",
	"EVEN_TILE",
	"ODD_GRID_POINT",
	"ODD_TILE",
	GRID_POINT = 1,
	TILE = 2,
	EVEN_GRID_POINT = 3,
	EVEN_TILE = 4,
	ODD_GRID_POINT = 5,
	ODD_TILE = 6,
}
lib.SnapType = SnapType

---Snap a coordinate to the appropriate grid point or tile based on the
---snap type.
---@param coord number
---@param snap_type Core.SnapType
---@return number
local function snap_to(coord, snap_type)
	if snap_type == SnapType.GRID_POINT then
		return floor(coord + 0.5)
	elseif snap_type == SnapType.TILE then
		return floor(coord) + 0.5
	elseif snap_type == SnapType.EVEN_GRID_POINT then
		local snapped = floor(coord)
		if snapped % 2 ~= 0 then snapped = snapped + 1 end
		return snapped
	elseif snap_type == SnapType.EVEN_TILE then
		local snapped = floor(coord)
		if snapped % 2 ~= 0 then snapped = snapped - 1 end
		return snapped + 0.5
	elseif snap_type == SnapType.ODD_GRID_POINT then
		local snapped = floor(coord)
		if snapped % 2 == 0 then snapped = snapped + 1 end
		return snapped
	elseif snap_type == SnapType.ODD_TILE then
		local snapped = floor(coord)
		if snapped % 2 == 0 then snapped = snapped - 1 end
		return snapped + 0.5
	end

	return coord -- no snapping applied.
end
lib.snap_to = snap_to

---In an absolute grid with squares sized `gx`x`gy` and a global offset of
---`(ox, oy)`, find the square containing the point `(x, y)` and return its
---bounding box.
---@param x number
---@param y number
---@param gx number Horizontal grid size
---@param gy number Vertical grid size
---@param ox number Horizontal grid offset
---@param oy number Vertical grid offset
local function get_absolute_grid_square(x, y, gx, gy, ox, oy)
	local left = floor((x - ox) / gx) * gx + ox
	local top = floor((y - oy) / gy) * gy + oy
	local right = left + gx
	local bottom = top + gy
	return left, top, right, bottom
end
lib.get_absolute_grid_square = get_absolute_grid_square

---@param is_x_axis boolean True for X axis, false for Y axis
---@param length uint Total length of the axis in tiles
---@param target_parity 1|2 1 = odd, 2 = even
---@param half_pos int Position along the axis in half tiles
---@return Core.SnapType snap_type World space cursor snapping method
---@return int offset Further bbox offset adjustment along this axis
local function compute_single_axis_snap_type(
	is_x_axis,
	length,
	target_parity,
	half_pos
)
	local offset = 0
	local int_length = floor(length)
	local half_pos_mod_4 = half_pos % 4

	if int_length % 2 == 0 then
		-- BLUEPRINT IS EVEN SIZE ALONG THIS AXIS
		-- Center will be on grid point, meaning we are SnapType 1,3,5
		--
		-- This case seems to be relatively straightforward.
		if target_parity == 1 then
			-- Target parity is odd. If we are a multiple of 4 halfsteps away,
			-- our parity must also be odd.
			if half_pos_mod_4 == 0 then
				return SnapType.ODD_GRID_POINT, offset
			else
				return SnapType.EVEN_GRID_POINT, offset
			end
		else
			if half_pos_mod_4 == 0 then
				return SnapType.EVEN_GRID_POINT, offset
			else
				return SnapType.ODD_GRID_POINT, offset
			end
		end
	else
		-- BLUEPRINT IS ODD SIZE ALONG THIS AXIS
		-- Center will be between grid points, meaning we are SnapType 2,4,6
		--
		-- Tbh I have no idea why this works. I derived it by testing a number
		-- of "evil" blueprints in game and tweaking until I got the right answers.
		--
		-- The essential idea is counting the number of half-tile steps to the
		-- entity that needs to be snapped, and then making sure the snap point
		-- ends up giving the target entity the desired parity. Since we're
		-- working with two-tile snapping, half-steps mod 4 should be the key
		-- deciding factor.
		--
		-- However, half of this stuff makes no sense. Why does the total length
		-- mod 4 matter? Why do I need an offset at all? Why do i have to flip
		-- things when the position is negative? (left/above the center of bpspace?)
		-- I have absolutely no idea.
		local length_mod_4 = int_length % 4
		local different_mod_4 = (half_pos_mod_4 ~= length_mod_4)
		local SAME_OFFSET = 1
		local DIFFERENT_OFFSET = 0

		-- Why?????
		if half_pos < 0 then
			strace.trace("BPLIB: SNAP: flipping half_pos and offsets")
			half_pos = -half_pos
			SAME_OFFSET = 0
			DIFFERENT_OFFSET = 1
		end

		strace.trace(
			"BPLIB: SNAP: odd length=",
			length,
			"mod 4=",
			length_mod_4,
			"half_pos=",
			half_pos,
			"mod 4=",
			half_pos_mod_4,
			"target_parity=",
			target_parity
		)

		-- Why?????
		local ODD_TILE, EVEN_TILE =
			length_mod_4 == 1 and SnapType.ODD_TILE or SnapType.EVEN_TILE,
			length_mod_4 == 1 and SnapType.EVEN_TILE or SnapType.ODD_TILE

		if target_parity == 1 then
			-- We want the destination coordinate to have odd parity.
			if half_pos_mod_4 == 0 then
				return ODD_TILE, 0
			elseif half_pos_mod_4 == 1 then
				-- Center of an even tile shifted by 1 half step
				-- gives an odd grid point.
				return EVEN_TILE, different_mod_4 and DIFFERENT_OFFSET or SAME_OFFSET
			elseif half_pos_mod_4 == 2 then
				return ODD_TILE, 0
			else
				-- half_pos % 4 == 3
				return EVEN_TILE, different_mod_4 and DIFFERENT_OFFSET or SAME_OFFSET
			end
		else
			if half_pos_mod_4 == 0 then
				return EVEN_TILE, offset
			elseif half_pos_mod_4 == 1 then
				return ODD_TILE, offset
			elseif half_pos_mod_4 == 2 then
				return EVEN_TILE, offset
			else
				-- half_pos % 4 == 3
				return ODD_TILE, offset
			end
		end
	end
end

---Get information on how the cursor position needs to be snapped when placing
---a blueprint with relative positioning.
---@param bbox BoundingBox Transformed bpspace bbox.
---@param snap_entity BlueprintEntity? Entity governing snapping, if any
---@param snap_entity_pos MapPosition? Transformed bpspace position of the snap entity.
---@param bp_rot_n int? Rotation of the blueprint in 90 degree increments.
---@return Core.SnapType xsnap Snapping type for the X-axis.
---@return Core.SnapType ysnap Snapping type for the Y-axis.
---@return int xofs Offset to apply to the X-axis.
---@return int yofs Offset to apply to the Y-axis.
function lib.get_bp_relative_snapping(
	bbox,
	snap_entity,
	snap_entity_pos,
	bp_rot_n
)
	local l, t, r, b = bbox_get(bbox)
	local w, h = r - l, b - t
	local xsnap, ysnap = SnapType.GRID_POINT, SnapType.GRID_POINT
	local xofs, yofs = 0, 0
	if not snap_entity then
		-- Simple snapping to tile or grid point.
		if floor(w) % 2 ~= 0 then xsnap = SnapType.TILE end
		if floor(h) % 2 ~= 0 then ysnap = SnapType.TILE end
		return xsnap, ysnap, xofs, yofs
	end

	-- Find snap entity
	local proto = prototypes.entity[snap_entity.name]
	local snap_table =
		geom_lib.get_custom_geometry(proto.type, proto.name, snap_entity.direction)
	if not snap_table then
		-- XXX: this should never happen
		return xsnap, ysnap, xofs, yofs
	end
	local snap_target_parity = { snap_table[5], snap_table[6] }
	if bp_rot_n % 2 == 1 then
		-- Swap x and y parities if the blueprint is rotated.
		snap_target_parity[1], snap_target_parity[2] =
			snap_target_parity[2], snap_target_parity[1]
	end

	-- Compute number of half integer steps from origin to controlling snap
	-- entity pos.
	local cx, cy = (l + r) / 2, (t + b) / 2
	local spos = pos_new(snap_entity_pos)
	pos_add(spos, -1, { cx, cy })

	strace.trace(
		"BPLIB: snap target parity for entity '",
		snap_entity.name,
		"' in direction",
		snap_entity.direction,
		"is (",
		snap_target_parity[1],
		",",
		snap_target_parity[2],
		"). Distance to origin is",
		spos
	)

	spos[1] = round(spos[1] / 0.5, 1)
	spos[2] = round(spos[2] / 0.5, 1)

	strace.trace(
		"BPLIB: snap entity rounded half-tile distance to origin is (",
		spos[1],
		",",
		spos[2],
		")"
	)

	-- Find center parity that yields desired parity at snap entity position.
	xsnap, xofs =
		compute_single_axis_snap_type(true, w, snap_target_parity[1], spos[1])
	ysnap, yofs =
		compute_single_axis_snap_type(false, h, snap_target_parity[2], spos[2])

	return xsnap, ysnap, xofs, yofs
end

return lib
