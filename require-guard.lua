-- Implementation of require guards to prevent modules from being multi-loaded
-- in the same Lua namespace. You should only use this when modules may actually
-- clobber shared data.

if not _G.__require_guard then _G.__require_guard = {} end

---Raise a Lua error if this module has already been loaded.
---@param name string Unique name of the module.
return function(name)
	if _G.__require_guard[name] then
		error(
			"Module '"
				.. name
				.. "' has already been loaded in this Lua environment and may not be loaded twice."
		)
	end
	_G.__require_guard[name] = true
end
