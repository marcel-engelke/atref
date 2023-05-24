---@diagnostic disable-next-line: unknown-cast-variable
---@cast peripheral peripheral
---@diagnostic disable-next-line: unknown-cast-variable
---@cast gps gps

local const = require("lib.const")

---@param args table The arguments provided to the program
local function setup(args)
	local modem = peripheral.find("modem")
	if not modem then
		print("No modem found, exiting!")
		---@diagnostic disable-next-line: undefined-global
		exit()
	end
	---@cast modem modem

	local argparse = require("lib.argparse")
	argparse.add_arg("log_ch", "-lc", "number", false, 9000)
	argparse.add_arg("log_lvl", "-ll", "string", false, "info")
	argparse.add_arg("master_ch", "-mc", "number", false, 10000)
	argparse.add_arg("listen_ch", "-c", "number", true)
	-- TODO determine direction by myself and make this optinal
	argparse.add_arg("direction", "-d", "string", true, nil, const.DIRECTIONS)

	local parsed_args, e = argparse.parse(args)
	if not parsed_args then
		print(e)
		---@diagnostic disable-next-line: undefined-global
		exit()
	end
	---@cast parsed_args table

	local log_ch = parsed_args.log_ch
	---@cast log_ch integer
	local log_lvl = parsed_args.log_lvl
	---@cast log_lvl log_level
	local listen_ch = parsed_args.listen_ch
	---@cast listen_ch integer
	local master_ch = parsed_args.master_ch
	---@cast master_ch integer

	local logger = require("lib.logger").setup(log_ch, log_lvl, nil, modem)
	---@cast logger logger

	local dir = parsed_args.direction
	---@cast dir gpslib_direction
	local x, y, z = gps.locate()
	local pos = {
		x = x,
		y = y,
		z = z,
		dir = dir
	}

	local queue = require("lib.queue").queue
	local worker = require("lib.worker.master").setup(logger)
	local message = require("lib.message.master").setup(modem, listen_ch, logger, {}, master_ch, queue)
	local gpslib = require("lib.gpslib.master").setup(worker, logger)
	local task = require("lib.task").master_setup(message.send_cmd, worker, logger)
	local routine = require("lib.routine").setup(task, worker, logger)

	return logger, gpslib, message, pos, routine, task, worker
end

local logger, gpslib, message, pos, routine, task, worker = setup({ ... })


-- TODO get rid of this
local function test_master()
	-- worker.create("dev-worker-1", "miner", 8001)
	-- worker.create("dev-worker-2", "miner", 8002)
	-- worker.create("dev-worker-3", "miner", 8003)
	worker.create("dev-worker-4", "miner", 8004)
	worker.deploy("dev-worker-4")

	local w_pos = {}
	---@param p gpslib_position
	local function reset(p)
		p.x = pos.x
		p.y = pos.y - 1
		p.z = pos.z
	end
	reset(w_pos)
	w_pos.dir = pos.dir

	local tid = task.create("dev-worker-4", "set_position", { pos = w_pos })
	task.create("dev-worker-4", "refuel", { target = 1000 })

	w_pos.x = w_pos.x - 25
	w_pos.y = w_pos.y - 5
	w_pos.z = w_pos.z - 10
	tid = task.create("dev-worker-4", "tunnel_pos", { pos = w_pos })
	-- tid = task.create("dev-worker-4", "navigate_pos", { pos = w_pos })
	task.await(tid)
	reset(w_pos)
	tid = task.create("dev-worker-4", "tunnel_pos", { pos = w_pos })
	-- tid = task.create("dev-worker-4", "navigate_pos", { pos = w_pos })
	task.await(tid)
	worker.collect("dev-worker-4")

	-- local dim = {
	-- l = 3,
	-- w = 3,
	-- h = 6,
	-- }
	-- routine.auto_mine(dim, "left", 1)
end

---@diagnostic disable-next-line: undefined-global
parallel.waitForAll(message.listen, gpslib.monitor, task.monitor, test_master)
