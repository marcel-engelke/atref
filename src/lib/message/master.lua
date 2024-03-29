---@diagnostic disable-next-line: unknown-cast-variable
---@cast os os

local controllable = require("lib.message.controllable")
local const = require("lib.const")

local function init(modem, listen_ch, logger, masters, master_ch, queue)
	---@class lib_message_master: lib_message_controllable Communication functionality for master computers
	local lib = controllable.init(modem, listen_ch, logger, masters, master_ch, queue)

	lib.msg_types["res"] = true
	lib.msg_types["gps"] = true

	local status_types = {
		err = true,
		ok = true,
	}

	---@param msg msg
	function lib.validators.res(msg)
		if not msg.payload.status
			or not status_types[msg.payload.status]
		then
			logger.trace("dropped: malformed res")
			return false
		end
		return true
	end

	---@param msg msg
	function lib.validators.gps(msg)
		if not msg.payload.body
			or type(msg.payload.body) ~= "table"
		then
			logger.trace("dropped: malformed gps")
			return false
		end
		for _, c in ipairs({ "x", "y", "z" }) do
			if not msg.payload.body[c]
				or type(msg.payload.body[c]) ~= "number"
			then
				logger.trace("dropped: malformed gps (coordinates)")
				return false
			elseif not msg.payload.body.dir
				or not const.DIRECTIONS[msg.payload.body.dir]
			then
				logger.trace("dropped: malformed gps (direction)")
				return false
			end
		end
		return true
	end

	---@param msg msg
	function lib.handlers.res(msg)
		os.queueEvent("task_update", msg.payload.id, msg.payload.status, msg.payload.body)
	end

	---@param msg msg
	function lib.handlers.gps(msg)
		os.queueEvent("gps_update", msg)
	end

	function lib.send_cmd(ch, rec_name, payload)
		lib.send_msg(ch, rec_name, "cmd", payload)
	end

	return lib
end

return {
	init = init
}
