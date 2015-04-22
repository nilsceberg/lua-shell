#!/bin/lua

local posix = require "posix"

local sh = require "shlib"
local task = require "task"

local lush = {}

function run(task)
	-- Walk back to the beginning of the command chain
	while task._prev ~= nil do
		task = task._prev
	end

	-- Then start all the processes
	local jobs = {}
	repeat
		local pid = posix.fork()
		if pid == 0 then
			posix._exit(task._func())
		else
			jobs[pid] = true
		end
		task = task._next
	until task == nil

	for p,d in pairs(jobs) do
		print(string.format("[job %d started]", p))
	end

	local done = false
	while not done do
		done = true
		for p,d in pairs(jobs) do
			rpid, stat = posix.wait()
			if stat == "killed" or stat == "exited" then
				print(string.format("[job %d done]", rpid))
				jobs[rpid] = nil
			end
			done = false
		end
	end
end

function lush.start()
	setmetatable(_G,
		{
			__index = function(tab, func)
				return function(...)
					local args = {...}
					return task.resolve(func, args)
				end
			end
		})
end

function lush.prompt()
	return string.format("\x1b[32m[%s@%s:%s (git?)] [%s]\n\x1b[31m$\x1b[0m ", os.getenv("USER"), os.getenv("HOST"), "~", "00:00:00")
end

function lush.prompt_continue()
	return "> "
end

function match_name(line)
	return line:match("^%s*[A-Za-z0-9_]+%s*$")
end

local running = true
function exit()
	running = false
end

function lush.repl()
	while running do
		lush.prompt()
		io.write(lush.prompt())
		local command = ""
		local line = io.read("*line")
		while line:match("\\$") do
			io.write(lush.prompt_continue())
			command = command .. line:match("(.+)\\$") .. "\n"
			line = io.read("*line")
		end
		command = command .. line
		
		if match_name(command) then
			command = command .. "()"
		end

		local func, err = load(command)
		if not func then print(string.format("\x1b[31m%s\x1b[0m", err)) end
		local status, result = pcall(load(command, "main", "t"))
		if not status then print(string.format("\x1b[31m%s\x1b[0m", result)) else
			--print("Return value: " .. tostring(result))
		end
	end
end

lush.start()
lush.repl()

