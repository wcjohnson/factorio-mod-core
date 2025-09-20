-- Ways in which Factorio entities can be oriented in the world.
-- This includes their possible directions and how they transform under
-- rotation and flipping.

local lib = {}

---An entity's orientation class specifies which orientations it can occupy
---as well as how it responds to rotation and flipping. Note that orientation
---classes can be somewhat dynamic; for example, assembling machines with
---active fluid recipes have a different orientation class than those without.
---
---Naming convention: `OC_(possible directions in hex)_(possible transformations)_(exceptional cases)`
---Possible transformations are:
--- - `R` = rotate clockwise (angle determined in context of possible directions)
--- - `F` = flip
--- - `S` = flip only if equivalent to a rotation
--- - lower case = as above but ONLY while held in cursor
--- - `c` = different behavior while held in cursor compared to placed
--- - `%` = transformation result reduced modulo symmetry (i.e. if southwest = northeast, northeast is returned)
---@enum Core.OrientationClass
local OrientationClass = {
	"OC_Unknown",
	"OC_Unsupported",
	"OC_0",
	"OC_04_r",
	"OC_04_R",
	"OC_04_RF",
	"OC_048C_R",
	"OC_048C_rs",
	"OC_048C_rS",
	"OC_048C_RS",
	"OC_048C_RSc",
	"OC_048CM_RF",
	"OC_048CM_RFc",
	"OC_048CM_latent",
	"OC_02468ACE_rf",

	---Unknown or unregistered entities that can't be classified.
	---Will be treated as OC_0.
	["OC_Unknown"] = 1,

	---Deliberately unsupported entities. Will be treated as OC_0.
	---[all rails/rail signals]
	["OC_Unsupported"] = 2,

	---No flip or rotation possible.
	["OC_0"] = 3,

	---North/east only, rotating interchanges them, flipping does nothing.
	---Hand only
	---[`steam-turbine`]
	["OC_04_r"] = 4,

	---North/east only, rotating interchanges them, flipping does nothing.
	---Transformation group = D8 / <r^2, s>.
	---[`fusion-reactor` with `two_direction_only=true`, ????]
	["OC_04_R"] = 5,

	---North/east only, flipping or rotating interchanges them.
	---Transformation group = D8 / <r^2, rs>.
	---[storage-tank with `two_direction_only=true`]
	["OC_04_RF"] = 6,

	---NESW, rotations only, no flips.
	---[`burner-mining-drill`]
	["OC_048C_R"] = 7,

	---NESW, rotations, flips when equivalent to a rotation, in-hand only
	---[`offshore-pump`]
	["OC_048C_rs"] = 8,

	---NESW, rotations, flips when equivalent to a rotation.
	---Rotation in hand only, flips in hand or world.
	---[`gun-turret`]
	["OC_048C_rS"] = 9,

	---NESW, rotations, flips only when equivalent to a rotation.
	---Transformation group = D8 / <s>
	---[`simple-entity-with-owner`, all belt, all inserter, `big-mining-drill`]
	["OC_048C_RS"] = 10,

	---NESW, rotations, flips only when equivalent to a rotation.
	---Transformation group = D8 / <s>
	---Rotation while in world = r^2
	---[`pump`, 1x2-combinators]
	["OC_048C_RSc"] = 11,

	---NESW + mirror bit
	---Transformation group = D8.
	---R = r, H = s, V = r^2*s
	---[AMs with active fluid boxes]
	["OC_048CM_RF"] = 12,

	---NESW + mirror bit, oblong shape, rotation = flip when placed
	---Transformation group = D8
	---While held: R = r, H = s, V = r^2*s
	---While in world:  R = r^2, H = s, V = r^2*s
	---[`recycler`]
	["OC_048CM_RFc"] = 13,

	---NESW + mirror bit, latent orientation. This applies to
	---assembling machines with disabled fluid boxes. If they are re-enabled
	---they become OC_048CM_RF and their latent orientation is restored.
	---(The orientation is still readable from world entities while they are
	--- latent, but they can't be changed.)
	["OC_048CM_latent"] = 14,

	---8-directional, sane transforms in hand, fixed when placed
	---[`railgun-turret`]
	["OC_02468ACE_rf"] = 15,
}
lib.OrientationClass = OrientationClass

---The context in which an entity orientation is being changed. Entities may
---behave differently when being held in cursor versus placed in the world.
---@enum Core.OrientationContext
local OrientationContext = {
	"Unknown",
	"Cursor",
	"World",
	"Blueprint",
	---Unknown context. (The more generous context will be used to interpret
	---transforms.)
	["Unknown"] = 1,
	---The entity is being held in the cursor.
	["Cursor"] = 2,
	---The entity is placed in the world.
	["World"] = 3,
	---The entity is in a blueprint which is itself being transformed.
	["Blueprint"] = 4,
}
lib.OrientationContext = OrientationContext

---Create the `mod-data` object for holding custom orientation classes.
---Calling this function outside the data phase will crash.
function lib.data_phase_create_mod_data()
	if not data.raw["mod-data"]["orientation-classes-by-name"] then
		data.raw["mod-data"]["orientation-classes-by-name"] = {
			type = "mod-data",
			name = "orientation-classes-by-name",
			data_type = "table<string, Core.OrientationClass>",
			data = {},
		}
	end
end

---During the data phase, register a custom modded entity's orientation
---class.
---@param entity_name string
---@param orientation_class Core.OrientationClass
function lib.data_phase_register_entity_orientation_class(
	entity_name,
	orientation_class
)
	lib.data_phase_create_mod_data()
	data.raw["mod-data"]["orientation-classes-by-name"].data[entity_name] =
		orientation_class
end

--- Prototype-types with fixed orientation classes
---@type table<string, Core.OrientationClass>
local static_by_type = {
	["container"] = OrientationClass.OC_0,
	["simple-entity-with-owner"] = OrientationClass.OC_048C_RS,
	["transport-belt"] = OrientationClass.OC_048C_RS,
	["underground-belt"] = OrientationClass.OC_048C_RS,
	["linked-belt"] = OrientationClass.OC_048C_RS,
	["splitter"] = OrientationClass.OC_048C_RS,
	["inserter"] = OrientationClass.OC_048C_RS,
	["loader"] = OrientationClass.OC_048C_RS,
	["electric-pole"] = OrientationClass.OC_0,
	["heat-pipe"] = OrientationClass.OC_0,
	["pipe"] = OrientationClass.OC_0,
	["pipe-to-ground"] = OrientationClass.OC_048C_RS,
	["pump"] = OrientationClass.OC_048C_RSc,
	["logistic-container"] = OrientationClass.OC_0,
	["roboport"] = OrientationClass.OC_0,
	["arithmetic-combinator"] = OrientationClass.OC_048C_RSc,
	["decider-combinator"] = OrientationClass.OC_048C_RSc,
	["selector-combinator"] = OrientationClass.OC_048C_RSc,
	["constant-combinator"] = OrientationClass.OC_048C_RS,
	["power-switch"] = OrientationClass.OC_0,
	["programmable-speaker"] = OrientationClass.OC_0,
	["lamp"] = OrientationClass.OC_0,
	["accumulator"] = OrientationClass.OC_0,
	["solar-panel"] = OrientationClass.OC_0,
	["lightning-attractor"] = OrientationClass.OC_0,
	["lab"] = OrientationClass.OC_0,
	["radar"] = OrientationClass.OC_0,
	["wall"] = OrientationClass.OC_0,
	["gate"] = OrientationClass.OC_04_R,
	["rocket-silo"] = OrientationClass.OC_0,
	["cargo-landing-pad"] = OrientationClass.OC_0,
	["cargo-bay"] = OrientationClass.OC_0,
	-- Unsupported rail entities
	["rail-signal"] = OrientationClass.OC_Unsupported,
	["rail-chain-signal"] = OrientationClass.OC_Unsupported,
	["straight-rail"] = OrientationClass.OC_Unsupported,
	["curved-rail-a"] = OrientationClass.OC_Unsupported,
	["curved-rail-b"] = OrientationClass.OC_Unsupported,
	["half-diagonal-rail"] = OrientationClass.OC_Unsupported,
}

---If a prototype type has a statically determined orientation class, return it.
---Otherwise, return nil.
---@param prototype_type string?
---@return Core.OrientationClass?
local function get_static_orientation_class_for_type(prototype_type)
	return static_by_type[prototype_type or ""]
end
lib.get_static_orientation_class_for_type =
	get_static_orientation_class_for_type

---Prototype-names with fixed orientation classes
---@type table<string, Core.OrientationClass>
local static_by_name = {
	["boiler"] = OrientationClass.OC_048C_RS,
	["steam-engine"] = OrientationClass.OC_04_r,
	["nuclear-reactor"] = OrientationClass.OC_0,
	["heat-exchanger"] = OrientationClass.OC_048C_RSc,
	["steam-turbine"] = OrientationClass.OC_04_r,
	["fusion-reactor"] = OrientationClass.OC_04_R,
	["fusion-generator"] = OrientationClass.OC_048C_RSc,
	["burner-mining-drill"] = OrientationClass.OC_048C_R,
	["electric-mining-drill"] = OrientationClass.OC_048C_RS,
	["big-mining-drill"] = OrientationClass.OC_048C_RS,
	["offshore-pump"] = OrientationClass.OC_048C_rs,
	["pumpjack"] = OrientationClass.OC_048C_R,
	["stone-furnace"] = OrientationClass.OC_0,
	["steel-furnace"] = OrientationClass.OC_0,
	["electric-furnace"] = OrientationClass.OC_0,
	["recycler"] = OrientationClass.OC_048CM_RFc,
	["agricultural-tower"] = OrientationClass.OC_0,
	["heating-tower"] = OrientationClass.OC_0,
	["gun-turret"] = OrientationClass.OC_048C_rS,
	["laser-turret"] = OrientationClass.OC_048C_rS,
	["flamethrower-turret"] = OrientationClass.OC_048C_rs,
	["artillery-turret"] = OrientationClass.OC_048C_RS,
	["rocket-turret"] = OrientationClass.OC_048C_rS,
	["tesla-turret"] = OrientationClass.OC_048C_rS,
	["railgun-turret"] = OrientationClass.OC_02468ACE_rf,
	-- AMs with always-on fluidboxes
	["chemical-plant"] = OrientationClass.OC_048CM_RF,
	["oil-refinery"] = OrientationClass.OC_048CM_RF,
	-- AMs with always-off fluidboxes
	["centrifuge"] = OrientationClass.OC_0,
}

---If a prototype name has a statically determined orientation class, return it.
---Otherwise, return nil.
---@param prototype_name string?
---@return Core.OrientationClass?
local function get_static_orientation_class_for_name(prototype_name)
	if not prototype_name then return nil end
	-- Check mod data first
	local custom = prototypes.mod_data["orientation-classes-by-name"]
	if custom then
		local c = custom[prototype_name]
		if c then return c end
	end
	-- Fallback on static determination for base game entities.
	return static_by_name[prototype_name]
end
lib.get_static_orientation_class_for_name =
	get_static_orientation_class_for_name

local function get_actual_type(entity)
	if entity.type == "entity-ghost" then
		return entity.ghost_type
	else
		return entity.type
	end
end

local function get_actual_name(entity)
	if entity.type == "entity-ghost" then
		return entity.ghost_name
	else
		return entity.name
	end
end

---Attempt to get dynamic orientation class from a world entity. Returns
---`nil` if the entity isn't known to have a dynamic class or the class
---can't be determined.
---@param entity LuaEntity A *valid* entity.
---@return Core.OrientationClass?
local function get_dynamic_orientation_class_for_entity(entity)
	if get_actual_type(entity) ~= "assembling-machine" then return nil end
	local fluidbox = entity.fluidbox
	if fluidbox and #fluidbox > 0 then
		return OrientationClass.OC_048CM_RF
	else
		return OrientationClass.OC_048CM_latent
	end
end
lib.get_dynamic_orientation_class_for_entity =
	get_dynamic_orientation_class_for_entity

---Get the orientation class for an entity or ghost.
---@param entity LuaEntity?
---@return Core.OrientationClass
function lib.get_orientation_class_for_entity(entity)
	if not entity or not entity.valid then return OrientationClass.OC_Unknown end
	return get_static_orientation_class_for_type(get_actual_type(entity))
		or get_static_orientation_class_for_name(get_actual_name(entity))
		or get_dynamic_orientation_class_for_entity(entity)
		or OrientationClass.OC_Unknown
end

return lib
