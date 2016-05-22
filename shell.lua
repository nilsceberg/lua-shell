#!/bin/lua

-- kind of a hack...
package.path = arg[0]:gsub("[^/]+$", "?/init.lua") .. ";" ..
				arg[0]:gsub("[^/]+$", "?.lua") .. ";" .. package.path

luashell = require "luashell"
local repl = require "luashell.repl"

local posix = require "posix"
local sig = require "posix.signal"

-- returns a string with tostring applied to all the arguments, separated
-- by commas
function stringify_multiple(first, ...)
	local rest = {...}
	return tostring(first) ..
		(#rest > 0 and (", " .. stringify_multiple(...)) or "")
end

local function interactive()
	-- repl settings table
	settings = {
		prompt = function()
			return string.format("%s $ ", posix.getcwd())
		end,
		prompt_continue = function()
			return "> "
		end,
		display_results = function(results)
			if #results > 0 then
				print(string.format("[%s]",
					stringify_multiple(unpack(results))))
			end
		end
	}

	-- run rc files
	do
		local home = os.getenv("HOME")
		local f = io.open(home .. "/.lushrc", "r")
		if f then
			f:close()
			dofile(home .. "/.lushrc")
		end
	end

	-- start shell
	local cmd_loop = repl.new(settings)

	function exit()
		cmd_loop.running = false
		return "goodbye!"
	end

	RETVAL=0
	-- loop until exit is called
	cmd_loop.running = true
	while cmd_loop.running do
		local results = cmd_loop:run_once()
		
		-- display result
		settings.display_results(results)

		-- make return value globally accessible
		-- (hasn't necessarily changed since last loop)
		RETVAL = cmd_loop.return_value
	end
end

local function main(args)
	sig.signal(sig.SIGINT, function()
		io.stderr:write("\n\x1b[31minterrupted\x1b[0m\n")
	end)

	-- load luashell functionality into global environment
	luashell.globalize()

	-- global variables
	MODE =
	{
		interactive = #args == 0
	}

	if MODE.interactive then
		interactive()
	else
		dofile(args[1])
	end
end

-- arg is a global table created by the Lua interpreter
main(arg)

