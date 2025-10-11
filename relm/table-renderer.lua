local type = type
local tostring = tostring
local SERPENT_ARGS = { maxlevel = 5, maxnum = 20, nocode = true }
local serpent_line = serpent.line
local tlib = require("lib.core.table")
local EMPTY = tlib.EMPTY
local relm = require("lib.core.relm.relm")
local ultros = require("lib.core.relm.ultros")

local Pr = relm.Primitive

local lib = {}

local function stringify(val)
	local val_t = type(val)
	if
		val_t == "nil"
		or val_t == "number"
		or val_t == "string"
		or val_t == "boolean"
	then
		return tostring(val)
	elseif val_t == "function" then
		return "(function)"
	else
		return serpent_line(val, SERPENT_ARGS)
	end
end
lib.stringify = stringify

local function default_renderer(k, v)
	return ultros.BoldLabel(k), ultros.RtMultilineLabel(stringify(v))
end
lib.default_renderer = default_renderer

---@alias Core.RelmTableRendererer fun(key: string|number, value: any, primitive_style: table): Relm.Children

---@param n_cols int Number of columns in the table. If 1, a vertical flow is used instead.
---@param tbl table Table to render.
---@param renderers {[string|number]: Core.RelmTableRendererer}? Optional renderers for specific keys.
---@param default Core.RelmTableRendererer? Default renderer if no specific renderer is found. If `nil`, entries without renderers are ignored.
---@param primdef table? Additional primitive definition fields to apply to the table or flow.
---@return Relm.Children
function lib.render_table(n_cols, tbl, renderers, default, primdef)
	renderers = renderers or EMPTY
	if primdef then
		primdef = tlib.assign({}, primdef)
	else
		primdef = { horizontally_stretchable = true }
	end

	local children = {}
	for k, v in pairs(tbl) do
		local renderer = renderers[k]
		if (renderer == nil) and default then renderer = default end
		if renderer then tlib.append(children, renderer(k, v, primdef)) end
	end
	if n_cols == 1 then
		primdef.type = "flow"
		primdef.direction = "vertical"
		return Pr(primdef, children)
	else
		primdef.type = "table"
		primdef.column_count = n_cols
		return Pr(primdef, children)
	end
end

return lib
