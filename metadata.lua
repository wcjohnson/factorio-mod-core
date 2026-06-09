--------------------------------------------------------------------------------
-- Reusable Metadata about Factorio entities, etc.
--------------------------------------------------------------------------------

local lib = {}

---Prototype-types that can connect to the circuit network
---@type {[string]: true}
local circuit_network_types = {
	["accumulator"] = true,
	["agricultural-tower"] = true,
	["ammo-turret"] = true,
	["arithmetic-combinator"] = true,
	["artillery-turret"] = true,
	["assembling-machine"] = true,
	["asteroid-collector"] = true,
	["cargo-landing-pad"] = true,
	["constant-combinator"] = true,
	["container"] = true,
	["decider-combinator"] = true,
	["display-panel"] = true,
	["electric-pole"] = true,
	["electric-turret"] = true,
	["furnace"] = true,
	["infinity-container"] = true,
	["inserter"] = true,
	["lamp"] = true,
	["linked-container"] = true,
	["loader-1x1"] = true,
	["loader"] = true,
	["logistic-container"] = true,
	["mining-drill"] = true,
	["offshore-pump"] = true,
	["power-switch"] = true,
	["programmable-speaker"] = true,
	["proxy-container"] = true,
	["pump"] = true,
	["radar"] = true,
	["rail-chain-signal"] = true,
	["rail-signal"] = true,
	["roboport"] = true,
	["rocket-silo"] = true,
	["selector-combinator"] = true,
	["space-platform-hub"] = true,
	["splitter"] = true,
	["storage-tank"] = true,
	["temporary-container"] = true,
	["train-stop"] = true,
	["transport-belt"] = true,
	["turret"] = true,
}

---Determine if a prototype-type can connect to the circuit network.
---@param ty string
function lib.type_can_connect_to_circuit_network(ty)
	return not not circuit_network_types[ty]
end

---@param name string Prototype name of the entity.
function lib.can_connect_to_circuit_network(name)
	local prototype = prototypes.entity[name]
	if not prototype then return false end
	if circuit_network_types[prototype.type] then return true end
	return prototype.get_max_circuit_wire_distance() > 0
end

return lib
