#!/bin/lua

package.path = "./?/init.lua;" .. package.path

local luashell = require "luashell"
local repl = require "luashell.repl"


-- repl settings table
settings = {
	prompt = function()
		return string.format("%s $ ", posix.getcwd())
	end,
	prompt_continue = function()
		return "> "
	end
}

-- load luashell functionality into global environment
luashell.globalize()

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
end

cmd_loop:run()

