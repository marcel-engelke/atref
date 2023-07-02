local const = require("lib.const")
local common = require("lib.command.common")
local util = require("lib.util")

---@diagnostic disable-next-line: unknown-cast-variable
---@cast os os

---@diagnostic disable-next-line: unknown-cast-variable
---@cast turtle turtle

---@param config lib_config
---@param logger lib_logger
---@param pos gpslib_position
---@param modem modem
---@param listen_ch integer
---@param s_slot integer | nil The slot to use for tool swapping
local function init(config, logger, pos, modem, listen_ch, s_slot)
	---@class lib_command_loader: lib_command_miner Commands for chunk loading mining turtles
	local lib = common.init(config, logger, pos)

	s_slot = s_slot or 1

	---@return boolean swapped true when the tool had to be swapped
	local function equip_pick()
		local swapped = false
		if util.has_item(const.ITEM_PICKAXE, s_slot) then
			local slot = turtle.getSelectedSlot()
			turtle.select(s_slot)
			turtle.equipRight()
			swapped = true
			turtle.select(slot)
		end
		return swapped
	end

	local function _swap()
		local slot = turtle.getSelectedSlot()
		turtle.select(s_slot)
		turtle.equipRight()
		turtle.select(slot)
	end

	function lib.swap(_)
		_swap()
		if util.has_item(const.ITEM_PICKAXE, s_slot) then
			modem.open(listen_ch)
		end
		return true, nil
	end

	lib._navigate = lib.navigate
	---@param params {direction: cmd_direction, distance: number}
	function lib.navigate(params)
		local swapped = equip_pick()
		local ok, err = lib._navigate(params)
		if swapped then
			_swap()
			-- The peripheral wrapper survives swapping, open channels do not
			modem.open(listen_ch)
			os.queueEvent("pos_update")
			-- Yield to allow the position update to be propagated
			sleep(1)
		end
		if not ok then
			logger.error(err)
			return false, "navigate command (loader) failed"
		end
		return true, nil
	end

	lib._navigate_pos = lib.navigate_pos
	---@param params {pos: gpslib_position}
	function lib.navigate_pos(params)
		local swapped = equip_pick()
		local ok, err = lib._navigate_pos(params)
		if swapped then
			_swap()
			-- The peripheral wrapper survives swapping, open channels do not
			modem.open(listen_ch)
			os.queueEvent("pos_update")
			-- Yield to allow the position update to be propagated
			sleep(1)
		end
		if not ok then
			logger.error(err)
			return false, "navigate_pos command (loader) failed"
		end
		return true, nil
	end

	lib._tunnel = lib.tunnel
	---@param params {direction: cmd_direction, distance: number}
	---@diagnostic disable-next-line: duplicate-set-field
	function lib.tunnel(params)
		local swapped = equip_pick()
		local ok, err = lib._tunnel(params)
		if swapped then
			_swap()
			-- The peripheral wrapper survives swapping, open channels do not
			modem.open(listen_ch)
			os.queueEvent("pos_update")
			-- Yield to allow the position update to be propagated
			sleep(1)
		end
		if not ok then
			---@cast err string
			logger.error(err)
			return false, "tunnel command (loader) failed"
		end
		return true, nil
	end

	lib._tunnel_pos = lib.tunnel_pos
	---@param params {direction: cmd_direction, distance: number}
	---@diagnostic disable-next-line: duplicate-set-field
	function lib.tunnel_pos(params)
		local swapped = equip_pick()
		local ok, err = lib._tunnel_pos(params)
		if swapped then
			_swap()
			-- The peripheral wrapper survives swapping, open channels do not
			modem.open(listen_ch)
			os.queueEvent("pos_update")
			-- Yield to allow the position update to be propagated
			sleep(1)
		end
		if not ok then
			---@cast err string
			logger.error(err)
			return false, "tunnel_pos command (loader) failed"
		end
		return true, nil
	end

	lib._dump = lib.dump
	function lib.dump()
		local swapped = equip_pick()
		local ok, err = lib._dump()
		if swapped then
			_swap()
			modem.open(listen_ch)
		end
		if not ok then
			logger.error(err)
			return false, "dump command (loader) failed"
		end
	end

	lib._refuel = lib.refuel
	---@param params {direction: cmd_direction, distance: number}
	---@diagnostic disable-next-line: duplicate-set-field
	function lib.refuel(params)
		local swapped = equip_pick()
		local ok, err = lib._refuel(params)
		if swapped then
			_swap()
			-- The peripheral wrapper survives swapping, open channels do not
			modem.open(listen_ch)
		end
		if not ok then
			---@cast err string
			logger.error(err)
			return false, "refuel command (loader) failed"
		end
		return true, nil
	end

	return lib
end

return {
	init = init
}
