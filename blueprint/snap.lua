--------------------------------------------------------------------------------
-- SNAPPING
-- Compute how blueprints snap.
--------------------------------------------------------------------------------
local bbox_lib = require("lib.core.math.bbox")
local pos_lib = require("lib.core.math.pos")
local geom_lib = require("lib.core.blueprint.custom-geometry")
local num_lib = require("lib.core.math.numeric")
local strace = require("lib.core.strace")
local table_lib = require("lib.core.table")

local lib = {}

local floor = math.floor
local bbox_get = bbox_lib.bbox_get
local pos_get = pos_lib.pos_get
local pos_new = pos_lib.pos_new
local pos_add = pos_lib.pos_add
local round = num_lib.round
local ZERO = { 0, 0 }
local pos_rotate_ortho = pos_lib.pos_rotate_ortho
local pos_set = pos_lib.pos_set
local floor_approx = num_lib.floor_approx
local EMPTY = table_lib.EMPTY

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

local function get_box_parity(bbox)
	local l, t, r, b = bbox_get(bbox)
	local px = floor(r - l) % 2
	local py = floor(b - t) % 2
	return px, py
end

local function get_snap_base(bbox, pos)
	local dx_parity, dy_parity = get_box_parity(bbox)
	local x, y = pos_get(pos)
	if dx_parity == 0 then
		x = floor(x + 0.5)
	else
		x = floor(x) + 0.5
	end
	if dy_parity == 0 then
		y = floor(y + 0.5)
	else
		y = floor(y) + 0.5
	end
	return x, y
end

-- TODO: This is a copypasta to avoid circular deps. Refactor later.
local function get_blueprint_entity_pos(
	bp_entity,
	bp_center,
	bp_rot_n,
	flip_horizontal,
	flip_vertical
)
	-- Get bpspace position
	local epos = pos_new(bp_entity.position)
	-- Move to central frame of reference
	pos_add(epos, -1, bp_center)
	-- Apply flip
	local rx, ry = pos_get(epos)
	if flip_horizontal then rx = -rx end
	if flip_vertical then ry = -ry end
	pos_set(epos, rx, ry)
	-- Apply blueprint rotation
	pos_rotate_ortho(epos, ZERO, -bp_rot_n)
	return epos
end

local function is_valid_box_snap_point(snap_point, box_parity_x, box_parity_y)
	-- 0 = point, 1 = tile center
	local point_parity_x = floor(snap_point[1] * 2) % 2
	local point_parity_y = floor(snap_point[2] * 2) % 2
	return point_parity_x == box_parity_x and point_parity_y == box_parity_y
end

---@param snap_point MapPosition
---@param snap_entity_pos MapPosition
local function is_valid_entity_snap_point(
	snap_point,
	snap_entity_pos,
	snap_parity_x,
	snap_parity_y
)
	local epos = pos_new(snap_entity_pos)
	pos_add(epos, 1, snap_point)
	local ex, ey = pos_get(epos)
	ex = floor_approx(ex)
	ey = floor_approx(ey)
	return (ex % 2) == snap_parity_x and (ey % 2) == snap_parity_y
end

-- Empirical snapping offset table.
-- Mod4 cases:
-- OddxOdd (1,1), (3,1), (1,3), (3,3)
-- EvenxOdd or OddxEven: (1,e), (3,e) or (e,1), (e,3)
local points_and_offsets = {
	-- Ring 0
	{ { 0, 0 }, { 1, 1 }, { 0, 0 } },
	-- Ring 1
	{
		{ 0.5, 0 },
		{ 0, 1 },
		{ -0.5, 0 },
		{ { 0, 1 }, { 0, 0 } },
		{
			{ -0.5, 0 },
			{ -0.5, 0 },
		},
	},
	{ { 0, 0.5 }, { 1, 0 }, { 0, -0.5 } },
	-- Ring 2
	{ { 1, 0 }, { 0, 1 }, { 0, 0 } },
	{
		{ 0.5, 0.5 },
		{ 1, 1 },
		{ 0.5, 0.5 },
		{ { 1, 1 }, { 1, 0 }, { 1, 1 }, { 1, 1 } },
		{ { 0.5, 0.5 }, { 0.5, -0.5 }, { 0.5, 0.5 }, { 0.5, 0.5 } },
	},
	{ { 0, 1 }, { 1, 0 }, { 0, 0 } },
	-- Ring 3
	{
		{ 1.5, 0 },
		{ 0, 1 },
		{ -0.5, 0 },
		{ { 0, 1 }, { 0, 1 } },
		{ { 0.5, 0 }, { -0.5, 0 } },
	},
	{ { 1, 0.5 }, { 0, 1 }, { 0, 0.5 } },
	{ { 0.5, 1 }, { 1, 0 }, { 0.5, 0 } },
	{ { 0, 1.5 }, { 1, 0 }, { 0, 0.5 } },
	-- Ring 4
	{
		{ 1.5, 0.5 },
		{ 0, 1 },
		{ 0.5, 0.5 },
		{ { 0, 0 }, { 0, 1 }, { 0, 1 }, { 0, 1 } },
		{ { 0.5, -0.5 }, { 0.5, 0.5 }, { 0.5, 0.5 }, { 0.5, 0.5 } },
	},
	{ { 1, 1 }, { 0, 0 }, { 0, 0 } },
	{
		{ 0.5, 1.5 },
		{ 1, 1 },
		{ 0.5, -0.5 },
		{ { 1, 1 }, { 1, 0 }, { 0, 1 }, { 1, 1 } },
		{ { 0.5, -0.5 }, { 0.5, 0.5 }, { -0.5, -0.5 }, { 0.5, -0.5 } },
	},
	-- Ring 5
	{ { 1.5, 1 }, { 0, 0 }, { 0.5, 0 } },
	{ { 1, 1.5 }, { 0, 0 }, { 0, 0.5 } },
	-- Ring 6
	{
		{ 1.5, 1.5 },
		{ 0, 1 },
		{ 0.5, -0.5 },
		{
			{ 1, 1 },
			{ 1, 0 },
			{ 0, 1 },
			{ 1, 1 },
		},
		{
			{ 0.5, -0.5 },
			{ -0.5, 0.5 },
			{ 0.5, -0.5 },
			{ -0.5, -0.5 },
		},
	},
}

---@param w integer Width of blueprint bbox in tiles
---@param h integer Height of blueprint bbox in tiles
---@return MapPosition offset
---@return MapPosition nudge
---@return MapPosition snap_point
local function find_global_grid_offset(
	w,
	h,
	snap_entity_pos,
	snap_parity_x,
	snap_parity_y
)
	local box_parity_x, box_parity_y = w % 2, h % 2
	for i = 1, #points_and_offsets do
		local pain = points_and_offsets[i]
		local point = pain[1]
		local offset = pain[2]
		local nudge = pain[3] or EMPTY
		local offsets = pain[4]
		local nudges = pain[5]
		local valid_box = is_valid_box_snap_point(point, box_parity_x, box_parity_y)
		local valid_entity = is_valid_entity_snap_point(
			point,
			snap_entity_pos,
			snap_parity_x,
			snap_parity_y
		)
		if valid_box and valid_entity then
			-- Mod-4 subcases
			local w_mod_4, h_mod_4 = w % 4, h % 4
			local case = nil
			if w_mod_4 == 1 and h_mod_4 == 1 then
				case = 1
			elseif w_mod_4 == 3 and h_mod_4 == 1 then
				case = 2
			elseif w_mod_4 == 1 and h_mod_4 == 3 then
				case = 3
			elseif w_mod_4 == 3 and h_mod_4 == 3 then
				case = 4
			elseif box_parity_x == 0 and h_mod_4 == 1 then
				case = 1
			elseif box_parity_x == 0 and h_mod_4 == 3 then
				case = 2
			elseif box_parity_y == 0 and w_mod_4 == 1 then
				case = 1
			elseif box_parity_y == 0 and w_mod_4 == 3 then
				case = 2
			end
			if case and offsets then offset = offsets[case] end
			if case and nudges then nudge = nudges[case] end
			local grid_offset_x, grid_offset_y = offset[1], offset[2]
			local nudge_x, nudge_y = nudge[1] or 0, nudge[2] or 0
			strace.trace(
				"BPLIB: SNAP: point",
				point,
				"is valid with offset",
				grid_offset_x,
				grid_offset_y,
				"nudge",
				nudge_x,
				nudge_y,
				"mod4s",
				w_mod_4,
				h_mod_4,
				case
			)
			-- game.print({
			-- 	"",
			-- 	"Point is ",
			-- 	serpent.line(point),
			-- 	" size is ",
			-- 	w,
			-- 	"x",
			-- 	h,
			-- 	" (mod4 case ",
			-- 	case,
			-- 	": ",
			-- 	w_mod_4,
			-- 	",",
			-- 	h_mod_4,
			-- 	") global grid offset is ",
			-- 	grid_offset_x,
			-- 	",",
			-- 	grid_offset_y,
			-- 	" nudge is ",
			-- 	nudge_x,
			-- 	",",
			-- 	nudge_y,
			-- })
			return { grid_offset_x, grid_offset_y }, { nudge_x, nudge_y }, point
		end
	end

	-- This should never happen.
	error("LOGIC ERROR: No valid global grid offset found.")
end

---@param snap_entity BlueprintEntity
local function get_snap_entity_geometry(
	snap_entity,
	bp_center,
	bp_rot_n,
	flip_horizontal,
	flip_vertical
)
	local proto = prototypes.entity[snap_entity.name]
	local snap_table =
		geom_lib.get_custom_geometry(proto.type, proto.name, snap_entity.direction)
	if not snap_table then
		-- XXX: this should never happen
		error(
			"LOGIC ERROR: No custom geometry for snap entity " .. snap_entity.name
		)
	end
	local snap_parity_x, snap_parity_y = snap_table[5], snap_table[6]
	-- Convert to mod 2 arithmetic
	snap_parity_x = (snap_parity_x == 2) and 0 or 1
	snap_parity_y = (snap_parity_y == 2) and 0 or 1
	-- Swap x and y parities if the blueprint is rotated.
	if bp_rot_n % 2 == 1 then
		snap_parity_x, snap_parity_y = snap_parity_y, snap_parity_x
	end
	local snap_entity_pos = get_blueprint_entity_pos(
		snap_entity,
		bp_center,
		bp_rot_n,
		flip_horizontal,
		flip_vertical
	)
	return snap_entity_pos, snap_parity_x, snap_parity_y
end

---@param cursor_pos MapPosition Cursor position in world space.
---@param bbox BoundingBox Transformed bpspace bbox.
---@param snap_entity BlueprintEntity|nil Entity governing snapping, if any
---@param bp_center? MapPosition Blueprint center in bpspace.
---@param bp_rot_n? int Blueprint rotation in 90 degree increments.
---@param flip_horizontal? boolean?
---@param flip_vertical? boolean?
---@param debug_render_surface LuaSurface? If given, debug graphics will be drawn on the given surface showing blueprint placement computations.
---@return MapPosition snap_point The snap point to use.
function lib.find_snap_point(
	cursor_pos,
	bbox,
	snap_entity,
	bp_center,
	bp_rot_n,
	flip_horizontal,
	flip_vertical,
	debug_render_surface
)
	if snap_entity then
		local x, y = pos_get(cursor_pos)
		local l, t, r, b = bbox_get(bbox)
		local w = floor_approx(r - l)
		local h = floor_approx(b - t)
		local snap_entity_pos, parity_x, parity_y = get_snap_entity_geometry(
			snap_entity,
			bp_center,
			bp_rot_n,
			flip_horizontal,
			flip_vertical
		)
		local offset, nudge =
			find_global_grid_offset(w, h, snap_entity_pos, parity_x, parity_y)
		local gl, gt, gr, gb =
			get_absolute_grid_square(x, y, 2, 2, offset[1], offset[2])
		if debug_render_surface then
			-- Debug: draw green box around computed absolute gridsquare
			rendering.draw_rectangle({
				color = { r = 0, g = 1, b = 0, a = 1 },
				width = 3,
				filled = false,
				left_top = { gl, gt },
				right_bottom = { gr, gb },
				surface = debug_render_surface,
				time_to_live = 1800,
			})
		end
		local square_center = pos_new((gl + gr) / 2, (gt + gb) / 2)
		if nudge then pos_add(square_center, 1, nudge) end
		return square_center
	else
		local x, y = get_snap_base(bbox, cursor_pos)
		return { x, y }
	end
end

return lib
