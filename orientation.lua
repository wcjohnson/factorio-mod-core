local lib = {}

---Tuple representation of an absolute orthogonal orientation for an entity in
---world space.
---tuple[1] is the `defines.direction` in world space onto which
---the -Y direction in entity space is mapped.
---tuple[2] indicates
---the handedness of the coordinate transformation; if `true`, then the
---+X direction in entity space is mapped onto the axis 90 deg clockwise from that
---given by the direction, otherwise it is mapped onto the axis
---counterclockwise from that given by the direction.
---@alias Core.OrthoOrientationAbsolute [ (0|4|8|12), boolean ]

---Representation of a relative orthogonal orientation (i.e. a difference between two absolute orientations).
--- tuple[1] is the number of clockwise 90° rotations to apply. (i.e. number of times user presses the `R` key in-game)
--- tuple[2] is whether to flip the orientation horizontally.
--- tuple[3] is whether to flip the orientation vertically.
---@alias Core.OrthoOrientationRelative [(0|1|2|3), boolean, boolean]

--- The absolute orientation that represents no rotation and no mirroring.
--- This is the orientation of a freshly placed entity with no flips/rots.
---@type Core.OrthoOrientationAbsolute
lib.ABSOLUTE_ZERO = { 0, false }

--- The relative orientation that represents no change.
--- This is the orientation that, when applied to any absolute orientation, yields that same absolute orientation.
---@type Core.OrthoOrientationRelative
lib.RELATIVE_IDENTITY = { 0, false, false }

---Get the absolute orientation of an entity in worldspace.
---@param entity LuaEntity
---@return Core.OrthoOrientationAbsolute
function lib.get_orientation_of_entity(entity)
	return { entity.direction, entity.mirroring }
end

---Get the relative transformation to be imposed on entities during `pre_build`
---@param context EventData.on_pre_build
---@return Core.OrthoOrientationRelative
function lib.get_pre_build_relative_orientation(context)
	return {
		math.floor(context.direction / 4),
		context.flip_horizontal,
		context.flip_vertical,
	}
end

--- Compute the relative orientation that, when applied to `from`, results in `to`.
---@param from Core.OrthoOrientationAbsolute
---@param to Core.OrthoOrientationAbsolute
---@return Core.OrthoOrientationRelative
function lib.diff(from, to)
	local rotation = (to[1] - from[1]) % 16 / 4
	local flip_h = from[2] ~= to[2]
	local flip_v = false
	if flip_h then
		rotation = (4 - rotation) % 4
		flip_v = true
	end
	return { rotation, flip_h, flip_v }
end

--- Apply a relative orientation to an absolute orientation, yielding a new absolute orientation.
---@param orientation Core.OrthoOrientationAbsolute
---@param relative Core.OrthoOrientationRelative
---@return Core.OrthoOrientationAbsolute
function lib.apply(orientation, relative)
	local rotation = (orientation[1] + relative[1] * 4) % 16
	local flip_h = relative[2]
	local flip_v = relative[3]
	if flip_h then
		rotation = (16 - rotation) % 16
		flip_v = not flip_v
	end
	return { rotation, flip_h }
end

return lib
