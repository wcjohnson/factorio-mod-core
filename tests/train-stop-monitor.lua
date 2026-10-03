local core_root = assert(arg[1], "Pass the path to the core library directory")
local module_path = core_root .. "\\train-stop-monitor.lua"

local function fixture(saved_storage)
	local handlers = {}
	local reads = {}
	local raised = {}
	local shared_storage = saved_storage or {}
	local on_decrease
	local api
	local tick = 0

	local function reload()
		handlers = {}
		local env = {
			storage = shared_storage,
			defines = {
				events = {
					on_tick = 1,
					on_object_destroyed = 2,
					on_train_changed_state = 3,
				},
				target_type = { entity = 1 },
				train_state = { wait_station = 1 },
			},
			script = { register_on_object_destroyed = function() end },
			require = function(name)
				if name == "lib.core.event" then
					return {
						bind = function(event, handler) handlers[event] = handler end,
						raise = function(event, stop, unit_number)
							raised[#raised + 1] = { event, stop, unit_number }
							if on_decrease then on_decrease(stop) end
						end,
					}
				elseif name == "lib.core.trains" then
					return {
						get_stop_from_train = function(train) return train.station end,
					}
				end
				error("Unexpected require: " .. name)
			end,
		}
		api = assert(loadfile(module_path, "t", env))()
	end

	reload()
	local f = { storage = shared_storage, raised = raised, reload = reload }

	function f.stop(id, count)
		local stop = { valid = true, type = "train-stop", unit_number = id }
		local reservations = count or 3
		setmetatable(stop, {
			__index = function(_, key)
				if key == "train_reservations_count" then
					assert(stop.valid, "Read reservations on an invalid entity")
					reads[#reads + 1] = id
					return reservations
				end
				error("Unexpected entity property: " .. key)
			end,
		})
		return stop, function(value) reservations = value end
	end

	function f.watch(stop) return api.watch_stop(stop) end
	function f.unwatch(stop) api.unwatch_stop(stop) end
	function f.depart(stop)
		handlers[3]({ train = { state = 2, station = stop }, old_state = 1 })
	end
	function f.arrive(stop)
		handlers[3]({ train = { state = 1, station = stop }, old_state = 2 })
	end
	function f.destroy(id) handlers[2]({ type = 1, useful_id = id }) end
	function f.on_decrease(handler) on_decrease = handler end
	function f.tick()
		reads = {}
		tick = tick + 1
		handlers[1]({ tick = tick })
		assert(#reads <= 4, "Exceeded the per-tick polling limit")
		local seen = {}
		for _, id in ipairs(reads) do
			assert(not seen[id], "Polled the same stop twice in one tick")
			seen[id] = true
		end
		return reads
	end
	function f.check_ring()
		local st = shared_storage._stop_monitor
		local cursor = st.polling_cursor
		local count = 0
		for _, watched in pairs(st.watched_stops) do
			if watched.polling_next then
				count = count + 1
				assert(watched.polling_next.polling_prev == watched)
				assert(watched.polling_prev.polling_next == watched)
			else
				assert(not watched.polling_prev)
			end
		end
		assert(count == (st.polling_count or 0))
		if count == 0 then
			assert(not cursor)
			return
		end
		local node = cursor
		for i = 1, count do
			assert(st.watched_stops[node.unit_number] == node)
			node = node.polling_next
			assert((node == cursor) == (i == count), "Broken polling ring")
		end
	end
	return f
end

local tests = {}

function tests.round_robin_and_limit()
	for _, size in ipairs({ 1, 2, 3, 4, 5, 13, 257 }) do
		local f = fixture()
		assert(#f.tick() == 0)
		for i = 1, size do
			local stop = f.stop(i)
			assert(f.watch(stop))
			f.depart(stop)
		end
		local budget = math.min(size, 4)
		for tick = 1, size do
			local reads = f.tick()
			assert(#reads == budget)
			for i = 1, budget do
				assert(reads[i] == ((tick - 1) * budget + i - 1) % size + 1)
			end
		end
		f.check_ring()
	end
end

function tests.idempotent_toggles_and_singleton()
	local f = fixture()
	local stop = f.stop(1)
	assert(f.watch(stop))
	assert(not f.watch(stop))
	assert(#f.tick() == 0)
	f.depart(stop)
	f.depart(stop)
	assert(#f.tick() == 1)
	f.check_ring()
	f.arrive(stop)
	f.arrive(stop)
	assert(#f.tick() == 0)
	f.check_ring()
	f.depart(stop)
	f.unwatch(stop)
	f.unwatch(stop)
	assert(#f.tick() == 0)
	f.check_ring()
end

function tests.small_rings_poll_once_per_tick()
	for size = 1, 3 do
		local f = fixture()
		for id = 1, size do
			local stop = f.stop(id)
			f.watch(stop)
			f.depart(stop)
		end
		for _ = 1, 10 do
			local reads = f.tick()
			assert(#reads == size)
			for id = 1, size do
				assert(reads[id] == id)
			end
			f.check_ring()
		end
	end
end

function tests.cursor_after_unwatch_or_unpoll()
	for _, operation in ipairs({ "unwatch", "arrive" }) do
		for _, removed_id in ipairs({ 1, 2, 3 }) do
			local f = fixture()
			local stops = {}
			for id = 1, 3 do
				stops[id] = f.stop(id)
				f.watch(stops[id])
				f.depart(stops[id])
			end
			f[operation](stops[removed_id])
			local st = f.storage._stop_monitor
			assert(st.polling_cursor.unit_number == (removed_id == 1 and 2 or 1))
			f.check_ring()
			local expected = {}
			for id = 1, 3 do
				if id ~= removed_id then expected[#expected + 1] = id end
			end
			assert(table.concat(f.tick(), ",") == table.concat(expected, ","))
			f[operation](stops[expected[1]])
			assert(st.polling_cursor.unit_number == expected[2])
			assert(table.concat(f.tick(), ",") == tostring(expected[2]))
			f[operation](stops[expected[2]])
			assert(not st.polling_cursor)
			assert(#f.tick() == 0)
			f.check_ring()
		end
	end
end

function tests.shrinking_ring_does_not_repeat()
	local f = fixture()
	local first = f.stop(1)
	local second, set_count = f.stop(2)
	local third = f.stop(3)
	for _, stop in ipairs({ first, second, third }) do
		f.watch(stop)
		f.depart(stop)
	end
	set_count(2)
	assert(table.concat(f.tick(), ",") == "1,2,3")
	assert(f.storage._stop_monitor.polling_cursor.unit_number == 1)
	assert(table.concat(f.tick(), ",") == "1,3")
	f.check_ring()
end

function tests.advanced_cursor_after_unwatch_or_unpoll()
	for _, operation in ipairs({ "unwatch", "arrive" }) do
		local f = fixture()
		local stops = {}
		for id = 1, 7 do
			stops[id] = f.stop(id)
			f.watch(stops[id])
			f.depart(stops[id])
		end
		assert(table.concat(f.tick(), ",") == "1,2,3,4")
		assert(f.storage._stop_monitor.polling_cursor.unit_number == 5)
		f[operation](stops[5])
		assert(f.storage._stop_monitor.polling_cursor.unit_number == 6)
		f[operation](stops[7])
		assert(f.storage._stop_monitor.polling_cursor.unit_number == 6)
		f.check_ring()
		assert(table.concat(f.tick(), ",") == "6,1,2,3")
		assert(f.storage._stop_monitor.polling_cursor.unit_number == 4)
		f.check_ring()
	end
end

function tests.cursor_removed_during_poll()
	for _, operation in ipairs({ "unwatch", "arrive" }) do
		local f = fixture()
		local stops = {}
		local set_count
		for id = 1, 3 do
			local stop, setter = f.stop(id)
			stops[id] = stop
			if id == 1 then set_count = setter end
			f.watch(stop)
			f.depart(stop)
		end
		f.on_decrease(function()
			assert(f.storage._stop_monitor.polling_cursor.unit_number == 2)
			f[operation](stops[2])
			assert(f.storage._stop_monitor.polling_cursor.unit_number == 3)
		end)
		set_count(2)
		local expected = operation == "arrive" and "1,2,3" or "1,3"
		assert(table.concat(f.tick(), ",") == expected)
		assert(f.storage._stop_monitor.polling_cursor.unit_number == 3)
		assert(table.concat(f.tick(), ",") == "3")
		f.check_ring()
	end
end

function tests.decrease_and_reentrant_removal()
	local f = fixture()
	local first, set_count = f.stop(1)
	local second = f.stop(2)
	local third = f.stop(3)
	for _, stop in ipairs({ first, second, third }) do
		f.watch(stop)
		f.depart(stop)
	end
	f.on_decrease(function(stop)
		assert(stop == first)
		assert(not f.storage._stop_monitor.watched_stops[1].polling_next)
		f.unwatch(second)
		f.unwatch(third)
	end)
	set_count(2)
	local reads = f.tick()
	assert(#reads == 1 and reads[1] == 1)
	assert(#f.raised == 1)
	assert(f.raised[1][1] == "trainlib.reservation_count_decreased")
	assert(f.raised[1][2] == first and f.raised[1][3] == 1)
	assert(f.storage._stop_monitor.watched_stops[1].train_reservations_count == 2)
	f.check_ring()
	assert(#f.tick() == 0)
end

function tests.invalid_and_destroyed_stops()
	local f = fixture()
	local stops = {}
	for i = 1, 5 do
		stops[i] = f.stop(i)
		f.watch(stops[i])
		f.depart(stops[i])
	end
	stops[1].valid = false
	f.destroy(3)
	f.destroy(3)
	local reads = f.tick()
	assert(not f.storage._stop_monitor.watched_stops[1])
	for _, id in ipairs(reads) do
		assert(id ~= 1 and id ~= 3)
	end
	f.check_ring()
end

function tests.reload_and_old_storage()
	local f = fixture({ _stop_monitor = { watched_stops = {} } })
	assert(#f.tick() == 0)
	for i = 1, 7 do
		local stop = f.stop(i)
		f.watch(stop)
		f.depart(stop)
	end
	f.tick()
	f.reload()
	local reads = f.tick()
	assert(table.concat(reads, ",") == "5,6,7,1")
	f.check_ring()
end

function tests.toggle_stress()
	local f = fixture()
	local stops = {}
	for i = 1, 31 do
		stops[i] = f.stop(i)
		f.watch(stops[i])
	end
	for step = 1, 1000 do
		local stop = stops[(step * 17) % #stops + 1]
		local operation = step % 5
		if operation < 2 then
			f.depart(stop)
		elseif operation == 2 then
			f.arrive(stop)
		else
			f.unwatch(stop)
			f.watch(stop)
		end
		f.check_ring()
		f.tick()
		f.check_ring()
	end
end

local count = 0
for name, test in pairs(tests) do
	test()
	count = count + 1
	print("PASS " .. name)
end
print(count .. " tests passed")
