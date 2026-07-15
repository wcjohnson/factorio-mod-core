local tlib = require("lib.core.table")

local select = select
local type = type
local getmetatable = getmetatable

local lib = {}

local registered_metatables = {}

---Create a class metatable. If `name` is given, registers it with Factorio
---for serialization.
---@param name? string
---@param ... table #Mixins
function lib.class(name, ...)
	local mt = {}
	for i = 1, select("#", ...) do
		local arg = select(i, ...)
		if type(arg) == "table" then
			tlib.assign(mt, arg)
		else
			error(
				"Invalid argument #"
					.. i
					.. ": mixin must be a table, instead got "
					.. type(arg)
			)
		end
	end
	mt.classname = name
	mt.__index = mt
	if script and name then
		script.register_metatable(name, mt)
		registered_metatables[name] = mt
	end
	return mt
end

---Determine if an object is an instance of a class defined by `class`
---@param obj any
---@param mt table #Class metatable
function lib.instanceof(obj, mt)
	if type(obj) ~= "table" then return false end
	local obj_mt = getmetatable(obj)
	local n = 0
	while obj_mt do
		if obj_mt == mt then return true end
		obj_mt = getmetatable(obj_mt)
		n = n + 1
		if n > 100 then
			error(
				"Instanceof recursion max reached. Possible circular metatable reference"
			)
		end
	end
	return false
end

return lib
