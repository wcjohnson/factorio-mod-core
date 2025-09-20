local oclass = require("lib.core.orientation.orientation-class")
local dihedral = require("lib.core.math.dihedral")
local class = require("lib.core.class").class

local OC = oclass.OrientationClass
local OrientationContext = oclass.OrientationContext

local lib = {}

---Pure orientation data without the associated metaclass. Used when serializing
---to contexts like blueprints.
---@alias Core.OrientationData [Core.OrientationClass, integer, integer, 0|1]

---An object representing the current orientation state of an entity or ghost.
---@class Core.Orientation
local Orientation = class()
lib.Orientation = Orientation

---Order of the rotational element `r` in the dihedral group Dn used for this orientation class.
Orientation.dihedral_r_order = 4

---Entity implements flips only as 180° rotations.
Orientation.rotational_flips = false

---Entity can be rotated in world
Orientation.can_rotate_in_world = true

---Entity can be flipped in world
Orientation.can_flip_in_world = true

---Create a new Orientation object representing an entity of the given class
---facing true north and unflipped.
---@param oc Core.OrientationClass
function Orientation:new(oc)
	return setmetatable({ oc, self.dihedral_r_order, 0, 0 }, self)
end

---Clone an Orientation object.
---@return Core.Orientation
function Orientation:clone()
	-- Shallow copy is sufficient
	local clone = {}
	for k, v in pairs(self) do
		clone[k] = v
	end
	return setmetatable(clone, getmetatable(self))
end

---Get the `OrientationClass` of this orientation.
---@return Core.OrientationClass
function Orientation:get_class() return self[1] end

---Convert to a pure-data representation.
---@return Core.OrientationData
function Orientation:to_data() return { self[1], self[2], self[3], self[4] } end

---Equality of orientations.
---@param a Core.Orientation
---@param b Core.Orientation
function Orientation.__eq(a, b)
	if a[1] ~= b[1] then return false end
	return dihedral.exploded_eq(a[2], a[3], a[4], b[2], b[3], b[4])
end

---Transformation corresponding to a 90° clockwise rotation
---@param context Core.OrientationContext
---@return Core.Dihedral
function Orientation:R(context) return { self.dihedral_r_order, 1, 0 } end

---Transformation corresponding to a horizontal flip.
---@param context Core.OrientationContext
---@return Core.Dihedral
function Orientation:H(context) return { self.dihedral_r_order, 0, 1 } end

---Transformation corresponding to a vertical flip.
---@param context Core.OrientationContext
---@return Core.Dihedral
function Orientation:V(context)
	return { self.dihedral_r_order, math.floor(self.dihedral_r_order / 2), 1 }
end

---Appply a dihedral transform to this orientation in-place.
---The transform should be `self:R(context)`, `self:H(context)`, `self:V(context)`, or a product thereof.
---@param transform Core.Dihedral
function Orientation:apply(transform)
	self[2], self[3], self[4] = dihedral.exploded_product(
		self[2],
		self[3],
		self[4],
		transform[1],
		transform[2],
		transform[3]
	)
end

---Apply a transform from the group D8 to this orientation in-place.
---The transform needn't have come from R,H,V. It can be assumed to
---come from the `Blueprint` context.
---(All orientations must implement this because of blueprints, which have
---full D8 transform capabilities.)
---@param transform Core.Dihedral
function Orientation:apply_blueprint_transform(transform)
	return self:apply(transform)
end

---Extract the orientation of an entity or ghost into `self`. The orientation class
---of the given entity must be known in advance to match `self`.
---@param entity_or_ghost LuaEntity A *valid* entity or ghost of this orientation's class
function Orientation:extract(entity_or_ghost) end

---Impose the orientation represented by `self` onto the given entity or ghost.
---The orientation class of the given entity must be known in advance to match `self`.
---@param entity_or_ghost LuaEntity A *valid* entity or ghost of this orientation's class
function Orientation:impose(entity_or_ghost) end

---Map from orientation class to Lua class of Orientation objects.
---@type table<Core.OrientationClass, table>
local oc_to_lua_class = {
	[OC.OC_Unknown] = Orientation,
	[OC.OC_Unsupported] = Orientation,
	[OC.OC_0] = Orientation,
	[OC.OC_04_r] = Orientation,
	[OC.OC_04_R] = Orientation,
	[OC.OC_04_RF] = Orientation,
	[OC.OC_048C_R] = Orientation,
	[OC.OC_048C_rs] = Orientation,
	[OC.OC_048C_rS] = Orientation,
	[OC.OC_048C_RS] = Orientation,
	[OC.OC_048C_RSc] = Orientation,
	[OC.OC_048CM_RF] = Orientation,
	[OC.OC_048CM_RFc] = Orientation,
	[OC.OC_048CM_latent] = Orientation,
	[OC.OC_02468ACE_rf] = Orientation,
}

---Create an Orientation object representing the current orientation of
---the given entity or ghost.
---@param entity LuaEntity
---@return Core.Orientation?
function lib.extract_orientation(entity)
	local oc = oclass.get_orientation_class_for_entity(entity)
	if not oc then return nil end
	local O = oc_to_lua_class[oc]:new(oc)
	if not O then return nil end
	-- TODO: impl
	return O
end

---Create an Orientation object from a pure data representation.
---@param data Core.OrientationData?
---@return Core.Orientation?
function lib.hydrate_orientation(data)
	if not data then return nil end
	local oc = data[1]
	local lua_class = oc_to_lua_class[oc]
	if not lua_class then return nil end
	local O = lua_class:new(oc)
	O:from_data(data)
	return O
end

return lib
