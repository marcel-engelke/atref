local helpers = require("lib.helpers")
local queue = require("lib.queue")
local term = require("lib.testing.term")

-- TODO test runtime to run all tests in this project

-- Provide unit testing capabilities. See the relevant functions for their respective usage.
-- Overview:
--   Mock (global) functions with Testing.fn().
--   Mock function return values with Testing.set_return().
--   Create and run a unit test with Testing.test().
--   Create assertions with Testing.assert().
--   The test files are meant to be executed by a command line lua interpreter.
--   See example.test.lua for usage examples.
---@class lib_testing
---@field mockups {[string]: {[string]: fun(...)}}
---@field _functions { [string]: { queue: queue, default: table | nil} }
---@field _tests { [string]: { total: integer, passed: integer, failed: integer }}
Testing = {
	_current_test = { total = 0, passed = 0, failed = 0 },
	_functions = {},
	_tests = {}
}

---@param msg string
local function print_err(msg)
	print(term.bg.red .. "ERROR" .. term.reset .. " " .. msg)
end
---@param msg string
local function print_fail(msg)
	print(term.bg.red .. "FAIL" .. term.reset .. "  " .. msg)
end
---@param msg string
local function print_pass(msg)
	print(term.bg.green .. term.fg.black .. "PASS" .. term.reset .. "  " .. msg)
end

-- Reset the following: Function queues and defaults, _current_test
function Testing.reset()
	for _, f in pairs(Testing._functions) do
		f.queue = helpers.table_copy(queue.queue)
		f.default = nil
	end
	Testing._current_test = { total = 0, passed = 0, failed = 0 }
end

-- Create and run a unit test.
-- Execture the code defined in test_fn, catch and print runtime errors.
-- Print a test summary.
---@param name string The name of the test as it gets printed to the terminal
---@param test_fn fun() The function containing all the test code to be run, including assertions
function Testing.test(name, test_fn)
	print("[test] " .. name)
	Testing._tests[name] = {
		total = 0,
		passed = 0,
		failed = 0
	}

	local ok, err = pcall(test_fn)
	if not ok then
		print_err("Caught Lua exception")
		print(err)
	end
	for k, v in pairs(Testing._current_test) do
		Testing._tests[name][k] = v
	end

	if not ok or Testing._tests[name].failed > 0 then
		print_fail(term.fg.bright_red .. "Test failed!" .. term.reset)
	end
	-- TODO summary for all tests
	local run_msg = ok and "executed successfully, "
		or term.fg.bright_red .. "failed to execute" .. term.reset .. ", "
	local total_msg = "assertions: " .. Testing._tests[name].total .. ", "
	local passed_msg = Testing._tests[name].passed == 0 and "passed: 0, "
		or "passed: " .. term.fg.bright_green .. Testing._tests[name].passed .. term.reset .. ", "
	local failed_msg = Testing._tests[name].failed == 0 and "failed: 0"
		or "failed: " .. term.fg.bright_red .. Testing._tests[name].failed .. term.reset
	print("[test summary] " .. run_msg .. total_msg .. passed_msg .. failed_msg .. "\n")
	Testing.reset()
end

-- Create and evaluate an assertion.
-- Compare the length and contents of both arrays and return whether the assertion was successful.
---@param name string The name of the assertion as it gets printed to the terminal
---@param expected any[] Array of expected values
---@param actual any[] Array of actual values
function Testing.assert(name, expected, actual)
	Testing._current_test.total = Testing._current_test.total + 1
	local trace = debug.traceback(nil, 2)
	-- TODO does nil get counted?
	local msg_prefix = "(Assertion) " .. name .. ": "
	if #expected ~= #actual then
		print_err(msg_prefix .. "Expected " .. #expected .. " values, but got " .. #actual)
		print(trace)
		return false
	end

	if not helpers.compare(expected, actual) then
		print_err(msg_prefix .. "Value mismatch \nExpected:")
		print(helpers.table_to_str(expected))
		print("Found:")
		print(helpers.table_to_str(actual))
		print(trace)
		Testing._current_test.failed = Testing._current_test.failed + 1
		return false
	end
	print_pass(msg_prefix .. term.fg.bright_green .. "ok" .. term.reset)
	Testing._current_test.passed = Testing._current_test.passed + 1
	return true
end

-- Create a function mock up that takes a variable number of arguments.
-- The mocked function returns queued mock values or pre-defined default values.
---@param name string
function Testing.fn(name, ...)
	Testing._functions[name] = {
		queue = helpers.table_copy(queue),
		default = nil
	}

	local q = Testing._functions[name].queue
	local function fn(...)
		if q.len > 0 then
			return table.unpack(q.pop())
		end
		return Testing._functions[name].default
	end
	return fn
end

---@param name string
function Testing.set_default_return(name, ...)
	Testing._functions[name].default = table.pack(...)
end

---@param name string
function Testing.set_return(name, ...)
	Testing._functions[name].queue.push(table.pack(...))
end

---@param name string
---@param count integer
function Testing.set_return_many(name, count, ...)
	for _ = 1, count do
		Testing.set_return(name, ...)
	end
end

-- Add pre-built mockups
local src_file = debug.getinfo(1, "S").source
src_file = string.sub(src_file, 2)
local mockups_file = string.gsub(src_file, "testing%.lua", "mockups.lua")
Testing.mockups = dofile(mockups_file)

return Testing