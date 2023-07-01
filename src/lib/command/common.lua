---@diagnostic disable-next-line: unknown-cast-variable
---@cast os os

local const = require("lib.const")
local go = require("lib.navigate").go
local util = require("lib.util")

local directions = {
	forward = true,
	back = true,
	up = true,
	down = true,
	left = true,
	right = true
}

---@param config lib_config
---@param logger lib_logger
---@param current_pos gpslib_position
local function init(config, logger, current_pos)
	---@class lib_command_common Common turtle commands
	local lib = {}
	lib.current_pos = current_pos

	lib.validators = {}
	---@param pos gpslib_position
	function lib.validators.gpslib_position(pos)
		if not pos then
			return false, "missing parameter 'pos'"
		end
		for _, v in pairs({ "x", "y", "z" }) do
			if not pos[v] then
				return false, "missing parameter 'pos." .. v .. "'"
			elseif type(pos[v]) ~= "number" then
				return false, "invalid parameter 'pos." .. v .. "'"
			end
			if not pos.dir then
				return false, "missing parameter 'pos.dir'"
			elseif not const.DIRECTIONS[pos.dir] then
				return false, "invalid parameter 'pos.dir'"
			end
		end
		return true, nil
	end

	---@param fuel_type util_fuel_type
	function lib.validators.fuel_type(fuel_type)
		if not const.FUEL_TYPES[fuel_type] then
			return false, "invalid fuel type '" .. fuel_type .. "'"
		end
		return true, nil
	end

	---@param params {direction: cmd_direction, distance: number}
	function lib.navigate(params)
		-- validate params
		if not params.direction then
			local e = "missing parameter direction"
			---@cast e string
			return false, e
		end
		if not directions[params.direction]
			or type(params.direction) ~= "string"
		then
			local e = "invalid parameter direction '" .. params.direction .. "'"
			---@cast e string
			return false, e
		end
		if not params.distance then
			local e = "missing parameter distance"
			---@cast e string
			return false, e
		end
		if type(params.distance) ~= "number" then
			local e = "invalid parameter distance '" .. params.distance .. "'"
			---@cast e string
			return false, e
		end
		local ok, err
		if turtle.getFuelLevel() < params.distance then
			ok, err = util.refuel(params.distance, config.fuel_type)
			if not ok then
				return false, err
			end
		end

		ok, err = go[params.direction](params.distance)
		if ok then
			return true
		else
			---@cast err string
			logger.error(err)
			return false, "navigate command failed"
		end
	end

	---@param params {pos: gpslib_position}
	function lib.navigate_pos(params)
		local ok, err = lib.validators.gpslib_position(params.pos)
		if not ok then
			---@cast err string
			logger.error(err)
			return false, "navigate_pos command failed"
		end
		ok, err = go.coords(lib.current_pos, params.pos)
		if not ok then
			---@cast err string
			logger.error(err)
			return false, "navigate_pos command failed"
		end
		return true, nil
	end

	---@return true, nil, number
	function lib.get_fuel()
		---@diagnostic disable-next-line: missing-return-value
		return true, nil, turtle.getFuelLevel()
	end

	---@param params { fuel_type: util_fuel_type }
	function lib.set_fuel_type(params)
		local ok, err = lib.validators.fuel_type(params.fuel_type)
		if not ok then
			---@cast err string
			logger.error(err)
			return false, "set_fuel_type command failed"
		end
		config.fuel_type = params.fuel_type
		return true, nil
	end

	---@param params { pos: gpslib_position }
	function lib.set_position(params)
		local ok, err = lib.validators.gpslib_position(params.pos)
		if not ok then
			---@cast err string
			logger.error(err)
			return false, "set_position command failed"
		end
		for k, v in pairs(params.pos) do
			lib.current_pos[k] = v
		end
		return true, nil
	end

	-- Trigger a gps position update
	function lib.update_position()
		os.queueEvent("pos_update")
		return true, nil
	end

	return lib
end

return {
	directions = directions,
	init = init
}
