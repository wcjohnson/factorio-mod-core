local events = require("lib.core.event")
local trains = require("lib.core.trains")

local lib = {}

-------------------------------------------------------------------------------
-- STORAGE
-------------------------------------------------------------------------------

---@class trainlib.WatchedStop
---@field stop LuaEntity The train stop being watched.
---@field unit_number int64 The unit number of the train stop.
---@field train_reservations_count int Last known number of train reservations for this stop.

---@alias trainlib.PollingBucket table<int64, true> Map from unit_number to a boolean indicating if the stop is being polled.

---@class trainlib.Storage
---@field watched_stops table<int64, trainlib.WatchedStop> Map from unit_number to the corresponding watched train stop.

local function get_storage()
	---@diagnostic disable-next-line: undefined-field
	local st = storage._stop_monitor
	if not st then
		st = {
			watched_stops = {},
		}
		---@diagnostic disable-next-line: inject-field
		storage._stop_monitor = st
	end
	return st --[[@as trainlib.Storage]]
end

---@return trainlib.WatchedStop?
local function get_watched(stop)
	local unit_number = stop.unit_number --[[@as int64]]
	local watched_stops = get_storage().watched_stops
	return watched_stops[unit_number]
end

-------------------------------------------------------------------------------
-- POLLING
-------------------------------------------------------------------------------

-- Number of stops to poll per tick.
local BUCKET_SIZE = 4

local function start_polling(stop) end

local function stop_polling_by_unit_number(unit_number) end

local function stop_polling(stop) end

---@param stop LuaEntity
---@param watched_stop trainlib.WatchedStop?
---@return boolean was_updated
local function update_stop(stop, watched_stop)
	if not watched_stop then return false end
	local trc = stop.train_reservations_count
	local wtrc = watched_stop.train_reservations_count
	watched_stop.train_reservations_count = trc

	if trc < wtrc then
		-- Reservation count decreased, stop polling and raise event
		stop_polling(stop)
		events.raise(
			"trainlib.reservation_count_decreased",
			stop,
			watched_stop.unit_number
		)
	end

	return trc ~= wtrc
end

local function do_poll(stop) end

local function stop_watching_by_unit_number(unit_number)
	local watched_stops = get_storage().watched_stops
	if not watched_stops[unit_number] then return end
	stop_polling_by_unit_number(unit_number)
	watched_stops[unit_number] = nil
end

---@param stop LuaEntity
---@return boolean
local function start_watching(stop)
	local unit_number = stop.unit_number --[[@as int64]]
	local watched_stops = get_storage().watched_stops
	if watched_stops[unit_number] then return false end
	local trc = stop.train_reservations_count

	watched_stops[unit_number] = {
		unit_number = unit_number,
		stop = stop,
		train_reservations_count = trc,
	}
	script.register_on_object_destroyed(stop)
	return true
end

-------------------------------------------------------------------------------
-- EVENTS
-------------------------------------------------------------------------------

-- On train arrive at station, update and stop polling
-- On train depart from station, start polling
-- On poll, if reservation count decreased, update and stop polling

local TT_ENTITY = defines.target_type.entity

events.bind(
	defines.events.on_object_destroyed,
	---@param ev EventData.on_object_destroyed
	function(ev)
		if ev.type ~= TT_ENTITY then return end
		local unit_number = ev.useful_id
		stop_watching_by_unit_number(unit_number)
	end
)

events.bind(defines.events.on_tick, function()
	-- Run polling
end)

local TS_WAIT_STATION = defines.train_state.wait_station

events.bind(
	defines.events.on_train_changed_state,
	---@param ev EventData.on_train_changed_state
	function(ev)
		local luatrain = ev.train
		local new_state = luatrain.state
		local old_state = ev.old_state

		if new_state == TS_WAIT_STATION then
			-- A train is arriving somewhere
			local stop = luatrain.station
			if stop then
				local watched_stop = get_watched(stop)
				if watched_stop then
					-- We can stop polling until train leaves, since reservation count can't possibly decrease until then.
					stop_polling(stop)
					-- Take the opportunity to run an update inline.
					update_stop(stop, watched_stop)
				end
			end
		elseif old_state == TS_WAIT_STATION then
			-- A train is leaving a station
			local stop = trains.get_stop_from_train(luatrain)
			if stop then
				local watched_stop = get_watched(stop)
				if watched_stop then
					-- Start polling again, since reservation count might decrease now.
					start_polling(stop)
					update_stop(stop, watched_stop)
				end
			end
		end
	end
)

-------------------------------------------------------------------------------
-- API
-------------------------------------------------------------------------------

---Registers a train stop for monitoring
---@param stop LuaEntity The train stop to register.
---@return boolean was_registered `true` if a train stop was successfully registered, `false` otherwise.
function lib.watch_stop(stop)
	if (not stop) or not stop.valid or (stop.type ~= "train-stop") then
		return false
	end
	return start_watching(stop)
end

---Unregisters a train stop previously registered by `watch_stop`. (Note that if a train stop is destroyed it is automatically unregistered and you do not need to call this method.)
---@param stop LuaEntity The train stop to unregister.
function lib.unwatch_stop(stop)
	if (not stop) or not stop.valid or (stop.type ~= "train-stop") then
		return false
	end
	stop_watching_by_unit_number(stop.unit_number)
end

return lib
