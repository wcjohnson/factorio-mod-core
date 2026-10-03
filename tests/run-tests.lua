if package.config:sub(1, 1) ~= "\\" then
	error("This test runner currently requires the Windows command shell")
end

local function quote(path) return '"' .. path .. '"' end

local function read_command(command)
	local pipe = assert(io.popen(command, "r"))
	local lines = {}
	for line in pipe:lines() do
		lines[#lines + 1] = line
	end
	local ok, reason, code = pipe:close()
	if not ok then
		error(command .. " failed: " .. tostring(reason) .. " " .. tostring(code))
	end
	return lines
end

local runner_path = arg[0]:gsub("/", "\\")
local tests_dir = runner_path:match("^(.*)\\[^\\]+$") or "."
local core_root =
	read_command("cd /d " .. quote(tests_dir .. "\\..") .. " && cd")[1]
if not core_root then error("Could not resolve the core library directory") end
tests_dir = core_root .. "\\tests"

-- Interpreter options occupy negative indices after the executable.
local interpreter_index = -1
while arg[interpreter_index - 1] do
	interpreter_index = interpreter_index - 1
end
local interpreter = arg[interpreter_index]
if not interpreter then
	error("Run this script with your local Lua interpreter")
end
interpreter = interpreter:gsub("/", "\\")
if
	interpreter:find("\\", 1, true)
	and not interpreter:match("^%a:\\")
	and interpreter:sub(1, 2) ~= "\\\\"
then
	local cwd = read_command("cd")[1]
	if not cwd then error("Could not resolve the working directory") end
	interpreter = cwd .. "\\" .. interpreter
end

local tests = read_command("dir /b /a-d " .. quote(tests_dir .. "\\*.lua"))
table.sort(tests)
local failed = 0
local count = 0
for _, name in ipairs(tests) do
	if name:lower() ~= "run-tests.lua" then
		count = count + 1
		print("\nRunning " .. name)
		io.stdout:flush()
		local ok, reason, code = os.execute(
			"cd /d "
				.. quote(core_root)
				.. " && "
				.. quote(interpreter)
				.. " "
				.. quote(tests_dir .. "\\" .. name)
				.. " "
				.. quote(core_root)
		)
		if not ok then
			failed = failed + 1
			print(
				"FAIL "
					.. name
					.. " ("
					.. tostring(reason)
					.. " "
					.. tostring(code)
					.. ")"
			)
		end
	end
end
if count == 0 then
	error("No standalone Lua integration tests found in " .. tests_dir)
end
print("\n" .. (count - failed) .. "/" .. count .. " test files passed.")
os.exit(failed == 0 and 0 or 1)
