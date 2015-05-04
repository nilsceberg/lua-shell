#!/bin/lua
local repl = require "luashell.repl"
dofile("luashell/init.lua")


-- global variables
HOME = os.getenv("HOME")

-- repl settings table
settings = {
	prompt = function()
		return string.format("%s $ ", posix.getcwd())
	end,
	prompt_continue = function()
		return "> "
	end
}

-- run rc files
local f = io.open(HOME .. "/.lushrc", "r")
if f then
	f:close()
	dofile(HOME .. "/.lushrc")
end
f = nil

-- start shell
local cmd_loop = repl.new(settings)

function exit()
	cmd_loop.running = false
end

cmd_loop:run();

