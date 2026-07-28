-- Tools to paint grids of slot buttons efficiently using custom paint.

local relm = require("lib.core.relm.relm")
local relm_util = require("lib.core.relm.util")

local strformat = string.format
local type = type
local abs = math.abs
local floor = math.floor
local pairs = pairs
local ipairs = ipairs
local noop = function() end
local tostring = tostring
local Pr = relm.Primitive

local EMPTY = setmetatable({}, {
	__newindex = noop,
})

local lib = {}

local function Boolean(x)
	if x then
		return true
	else
		return false
	end
end

local function si_format(count, divisor, si_symbol)
	if abs(floor(count / divisor)) >= 10 then
		count = floor(count / divisor)
		return strformat("%.0f%s", count, si_symbol)
	else
		count = floor(count / (divisor / 10)) / 10
		return strformat("%.1f%s", count, si_symbol)
	end
end

---@param count number
---@return string
local function format_signal_count(count)
	local absv = abs(count)
	return -- signals are 32bit integers so Giga is enough
		absv >= 1e9 and si_format(count, 1e9, "G") or absv >= 1e6 and si_format(
		count,
		1e6,
		"M"
	) or absv >= 1e3 and si_format(count, 1e3, "k") or tostring(count)
end

local BUTTON_ADD_PARAMS = {
	type = "choose-elem-button",
	elem_type = "signal",
}
local LOWER_ADD_PARAMS = {
	type = "label",
	style = "relm_label_signal_count",
	ignored_by_interaction = true,
}
local UPPER_ADD_PARAMS = {
	type = "label",
	style = "relm_label_signal_count_upper",
	ignored_by_interaction = true,
}

---Manual paint function for signal counts
---@param elem LuaGuiElement
---@param primitive_props table
---@param get_event_tags fun(): Tags
local function paint_buttons(elem, primitive_props, get_event_tags)
	local props = primitive_props.parent_props
	local default_style = props.button_style or "relm_slot_button_default"
	local enabled = (props.enabled == true)
	local iter1, iter2, iter3 = props.get_button_iterator()

	local function add_button()
		local button = elem.add(BUTTON_ADD_PARAMS)
		button.add(LOWER_ADD_PARAMS)
		return button
	end

	---@param button LuaGuiElement
	local function apply_button(
		button,
		button_index,
		signal,
		lower_value,
		upper_value,
		button_style,
		lower_color,
		upper_color,
		locked,
		tooltip
	)
		local is_enabled = enabled
		button.enabled = is_enabled
		button.elem_value = signal
		button.style = button_style or default_style

		local lower = button.children[1] --[[@as LuaGuiElement]]
		local upper = button.children[2] --[[@as LuaGuiElement?]]

		local count = lower_value or ""
		if type(count) == "number" then count = format_signal_count(count) end
		lower.caption = count
		if lower_color then lower.style.font_color = lower_color end

		if upper_value then
			if not upper then upper = button.add(UPPER_ADD_PARAMS) end
			local upper_count = upper_value or ""
			if type(upper_count) == "number" then
				upper_count = format_signal_count(upper_count)
			end
			upper.caption = upper_count
			if upper_color then upper.style.font_color = upper_color end
		else
			if upper then upper.caption = "" end
		end

		if is_enabled then
			local tag_base = get_event_tags()
			tag_base.button_index = button_index
			button.tags = tag_base
			button.locked = Boolean(locked)
		else
			button.tags = EMPTY
		end
	end

	local child_index = 1
	local children = elem.children

	for
		button_index,
		signal,
		lower_value,
		upper_value,
		button_style,
		lower_color,
		upper_color,
		locked,
		tooltip
	in iter1, iter2, iter3 do
		---@diagnostic disable-next-line: need-check-nil
		local button = children[child_index]
		if not button then button = add_button() end

		apply_button(
			button --[[@as LuaGuiElement]],
			button_index,
			signal,
			lower_value,
			upper_value,
			button_style,
			lower_color,
			upper_color,
			locked,
			tooltip
		)
		child_index = child_index + 1
	end

	-- Destroy excess buttons
	while #children >= child_index do
		---@diagnostic disable-next-line: need-check-nil
		children[child_index].destroy()
		child_index = child_index + 1
	end
end

local ON_GUI_ELEMENT_CHANGED = defines.events.on_gui_elem_changed
local ON_GUI_CLICK = defines.events.on_gui_click

---@alias SlotButtonGenerator fun(invariant: any, control: any): any, SignalID?, integer?, integer?, string?, Color?, Color?, boolean?, LocalisedString?

---@class SlotButtonTableProps
---@field column_count integer
---@field button_style? string
---@field enabled? boolean
---@field get_button_iterator fun(): SlotButtonGenerator, any, any
---@field style? string
---@field on_click? fun(button_index: integer, signal: SignalID?, gui_event: EventData.on_gui_click)
---@field on_change? fun(button_index: integer, signal: SignalID?, gui_event: EventData.on_gui_elem_changed)

lib.SlotButtonTable = relm.define(
	"SlotButtonTable",
	---@param props SlotButtonTableProps
	function(props)
		local function handler(_me, relm_event, _props)
			local gui_event = relm_event.event
			local elt = gui_event.element
			local tags = elt.tags
			local button_index = tags and tags.button_index
			if not button_index then return end
			if gui_event.name == ON_GUI_ELEMENT_CHANGED then
				local hdlr = _props.on_change
				if hdlr then return hdlr(button_index, elt.elem_value, gui_event) end
			elseif gui_event.name == ON_GUI_CLICK then
				local hdlr = _props.on_click
				if hdlr then return hdlr(button_index, elt.elem_value, gui_event) end
			end
		end

		return Pr({
			type = "table",
			column_count = props.column_count,
			manual_paint = paint_buttons,
			style = props.style or "slot_table",
			parent_props = props,
			message_handler = handler,
			on_click = props.on_click,
			on_change = props.on_change,
		})
	end
)

---Allow use of legacy button array iteration.
function lib.make_button_array_iterator(button_array)
	return function()
		return function(array, index)
			index = index + 1
			local button = array[index]
			if not button then return end
			return index,
				button.signal,
				button.count,
				button.upper,
				button.button_style,
				button.lower_color,
				button.upper_color,
				button.locked,
				button.tooltip
		end,
			button_array,
			0
	end
end

return lib
