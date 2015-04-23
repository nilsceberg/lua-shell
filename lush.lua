#!/bin/lua

posix = require "posix"
local readline = require "readline"

local sh = require "shlib"
local pipeline = require "pipeline"

lush = {}

function run(pipeline)
	local print = function() end -- disable debug output, lol

	print(string.format("[starting %d jobs in pipeline]", #pipeline._tasks))

	local jobs = {}
	local pipe = {fdin = nil, fdout = nil}
	for i, task in ipairs(pipeline._tasks) do
		-- set our input to output from last process
		local oldpipe = { fdin = pipe.fdin, fdout = pipe.fdout }

		-- unless we're about to create the last process or supposed to capture the output, we need to create
		-- a pipe to redirect output to
		if i ~= #pipeline._tasks or pipeline._capture_output then
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

			if i ~= #pipeline._tasks or pipeline._capture_output then
				-- if we're not the last process, we need to redirect out output
				-- to the next process' input
				print(string.format("[%d: %d -> 1]", i, pipe.fdout))
				posix.dup2(pipe.fdout, 1)
				posix.close(pipe.fdin) -- close our copy of the read fd
			end

			posix._exit(task.func(unpack(task.args)) or 0)
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

	-- if we're supposed to capture the output of the command
	-- (for command substition), read from the last pipe
	local output = nil
	if pipeline._capture_output then
		-- close our write fd
		posix.close(pipe.fdout)

		-- read output until eof
		print("[reading output]")
		output = ""
		local buffer = ""
		while true do
			buffer = posix.read(pipe.fdin, 1024)
			if buffer == "" then break end
			output = output .. buffer
		end
		
		-- trim trailing whitespace
		output = output:gsub("%s*$", "")

		-- close file descriptor
		posix.close(pipe.fdin)
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
	return 0, output
end

function lush.init()
	-- set up readline
	readline.set_options{ keeplines=1000, histfile='~/.lush_history' }
	
	-- setup __index on _G to allow for
	-- calling running system commands like lua functions
	setmetatable(_G,
		{
			__index = function(tab, func)
				return pipeline.resolve(func)
			end
		})

	-- global variables
	HOME = os.getenv("HOME")

	local f = io.open(HOME .. "/.lushrc", "r")
	if f then
		f:close()
		dofile(HOME .. "/.lushrc")
	end
end

function lush.prompt()
	return string.format("%s $ ", posix.getcwd())
end

function lush.prompt_continue()
	return "> "
end

local running = true
function exit()
	running = false
end

function lush.repl()
	while running do
		local command = ""
		local line = readline.readline(lush.prompt()) --io.read("*line")
		while line:match("\\$") do
			--io.write(lush.prompt_continue())
			command = command .. line:match("(.+)\\$") .. "\n"
			line = readline.readline(lush.prompt_continue()) --io.read("*line")
		end
		command = command .. line

		-- first, try returning whatever the command results in
		local func, err = load(string.format("return (%s)", command), "shell", "t")
		if func ~= nil then
			local status, result = pcall(func)
			
			if not status then
				-- an error occurred; print message
				print(string.format("\x1b[31m%s\x1b[0m", result))
			else
				-- we're good!
				-- handle return value
				
				-- if it's a command pipeline or a function, execute it
				if type(result) == "function" or (type(result) == "table" and result._cmd_magic == pipeline.MAGIC_NUMBER) then
					local status, result = pcall(result)
					if not status then
						print(string.format("\x1b[31m%s\x1b[0m", result))
					end
				elseif result then
					-- otherwise, just print it
					print(string.format("[%s]", tostring(result)))
				end
			end
		else
			-- if that is syntactically wrong, try without the return
			func = load(command, "shell", "t")

			-- if it still results in an error, the fault is the user's,
			-- so print the error message
			if not func then
				print(string.format("\x1b[31m%s\x1b[0m", err))
			else
				-- if we're good, run the command
				local status, result = pcall(func)

				-- check for errors and print message
				if not status then
					print(string.format("\x1b[31m%s\x1b[0m", result))
				end
			end
		end
	end
end

lush.init()
lush.repl()

