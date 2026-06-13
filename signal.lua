--------------------------------------------------------------------------------
-- Tools for the manipulation of circuit signals and filters.
--------------------------------------------------------------------------------

local tlib = require("lib.core.table")
local strace = require("lib.core.strace")

local type = type
local EMPTY = tlib.EMPTY

local lib = {}

---Get the `string` quality name from a `QualityID` value.
---@param quality_id QualityID?
---@return string?
local function get_quality_name(quality_id)
	if quality_id == nil then
		return nil
	elseif type(quality_id) == "string" then
		return quality_id
	else
		return quality_id.name
	end
end
lib.get_quality_name = get_quality_name

---Build blueprint logistic filters from signals and values. Signals in the array
---are mapped one-to-one with counts at the same index.
---@param signals SignalID[]
---@param counts? int32[]
---@param default_count? int32 A default count to use for any signal that doesn't have a corresponding count. If not provided, signals are dropped.
---@return BlueprintLogisticFilter[]
function lib.compose_blueprint_logistic_filters(signals, counts, default_count)
	---@type BlueprintLogisticFilter[]
	local filters = {}
	counts = counts or EMPTY
	for index, signal in ipairs(signals) do
		local count = counts[index] or default_count
		if count then
			local filter_index = #filters + 1
			filters[filter_index] = {
				index = filter_index,
				type = signal.type or "item",
				name = signal.name,
				quality = get_quality_name(signal.quality) or "normal",
				count = count,
				comparator = "=",
			}
		end
	end
	return filters
end

---Build runtime logistic filters from signals and values. Signals in the array are mapped one-to-one with counts at the same index.
---@param signals SignalID[]
---@param counts? int32[]
---@param default_count? int32 A default count to use for any signal that doesn't have a corresponding count. If not provided, signals are dropped.
---@return LogisticFilter[]
function lib.compose_logistic_filters(signals, counts, default_count)
	---@type LogisticFilter[]
	local filters = {}
	counts = counts or EMPTY
	for index, signal in ipairs(signals) do
		local count = counts[index] or default_count
		if count then
			---@type LogisticFilter
			local filter = {
				value = {
					type = signal.type or "item",
					name = signal.name,
					quality = get_quality_name(signal.quality) or "normal",
					comparator = "=",
				},
				min = count,
			}
			filters[#filters + 1] = filter
		end
	end
	return filters
end

---Compose a `ConstantCombinatorBlueprintControlBehavior` that will result in
---the blueprinted constant combinator outputting the given signals and counts
---in a single simple logistic section.
---@param signals SignalID[]
---@param counts? int32[]
---@param default_count? int32 A default count to use for any signal that doesn't have a corresponding count. If not provided, signals are dropped.
---@return ConstantCombinatorBlueprintControlBehavior? control_behavior
function lib.compose_simple_ccbpcb(signals, counts, default_count)
	---@type ConstantCombinatorBlueprintControlBehavior
	local control_behavior = {
		sections = {
			sections = {
				{
					index = 1,
					filters = lib.compose_blueprint_logistic_filters(
						signals,
						counts,
						default_count
					),
				},
			},
		},
	}
	return control_behavior
end

---Apply the given signals and counts to the given `LuaConstantCombinatorControlBehavior` as a single simple logistic section. Signals in the array are mapped one-to-one with counts at the same index.
---@param behavior LuaConstantCombinatorControlBehavior? The control behavior to apply the signals and counts to. If nil, the function does nothing.
---@param signals SignalID[]? Signals to assign; if `nil`, clears the combinator's signals.
---@param counts? int32[]
---@param default_count? int32 A default count to use for any signal that doesn't have a corresponding count. If not provided, signals are dropped.
---@return boolean success True if the operation was successful, false if anything went wrong.
function lib.apply_simple_cccb(behavior, signals, counts, default_count)
	if not behavior then return false end

	-- Normalize sections
	local n = behavior.sections_count
	local section = nil
	if n == 0 then
		section = behavior.add_section()
	elseif n == 1 then
		section = behavior.get_section(1)
	else
		section = behavior.get_section(1)
		for i = n, 2, -1 do
			behavior.remove_section(i)
		end
	end
	if not section then return false end
	strace.trace("section", section)
	if not signals then
		section.filters = tlib.EMPTY
		return true
	end

	local filters = lib.compose_logistic_filters(signals, counts, default_count)
	strace.trace("filters", filters)
	section.filters = filters
	return true
end

return lib
