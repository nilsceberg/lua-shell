#!/bin/lua

local posix = require "posix"

local sh = require "shlib"
local task = require "task"

local lush = {}

function run(pipeline)
	print(string.format("[starting %d jobs in pipeline]", #pipeline._tasks))

	local jobs = {}
	local pipe = {fdin = nil, fdout = nil}
	for i, task in ipairs(pipeline._tasks) do
		-- set our input to output from last process
		local oldpipe = { fdin = pipe.fdin, fdout = pipe.fdout }

		-- unless we're about to create the last process, we need to create
		-- a pipe to redirect output to
		if i ~= #pipeline._tasks then
			pipe.fdin, pipe.fdout = posix.pipe()
		end

		local pid = posix.fork()
		if pid == 0 then
			if i ~= 1 then
				-- if we're not the first process, we need to redirect the last
				-- process' output to our input
				print(string.format("[%d: %d -> 0]", i, oldpipe.fdin))
				posix.dup2(oldpipe.fdin, 0)
				posix.close(oldpipe.fdout) -- close our copy of the write fd
			end

			if i ~= #pipeline._tasks then
				-- if we're not the last process, we need to redirect out output
				-- to the next process' input
				print(string.format("[%d: %d -> 1]", i, pipe.fdout))
				posix.dup2(pipe.fdout, 1)
				posix.close(pipe.fdin) -- close our copy of the read fd
			end

			posix._exit(task.func(unpack(task.args)))
		else
			-- if we've piped stdout -> stdin to the newly spawned child,
			-- close the parent's copies of the pipe fd's
			if i ~= 1 then
				posix.close(oldpipe.fdin)
				posix.close(oldpipe.fdout)
			end

			jobs[pid] = true
		end
	end

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

	print("[all jobs done]")
end

function lush.start()
	setmetatable(_G,
		{
			__index = function(tab, func)
				return task.resolve(func)
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
		
		--if match_name(command) then
		--	command = command .. "()"
		--end

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

