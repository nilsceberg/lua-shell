local posix = require "posix"


local pipeline = {}
pipeline.MAGIC_NUMBER = 0x1209adb1 

local function encode_argument(argument)
	if type(argument) == "string" then
		return string.format("\"%s\"", argument:gsub("\"", "\\\""))
	end
end

local function encode_arguments(...)
	local args = ""
	for i, arg in ipairs({...}) do
		args = args .. encode_argument(arg) .. " "
	end
	return args
end

function pipeline.resolve(func)
	return pipeline.new(
		function(...)
			posix.execp(func, {...})
			return 0
		end
	)
end

pipeline.__index = function(self, func)
	if func == "run" then
		return pipeline.run
	end

	local new_pipeline = pipeline.resolve(func)

	local copy = self._copy()
	table.insert(copy._tasks, new_pipeline._tasks[1])
	return copy
end

pipeline.__call = function(self, ...)
	local args = {...}
	if #args == 0 then
		return self:run()
	else
		local copy = self._copy()
		for i, arg in ipairs(args) do
			if type(arg) == "string" then
				table.insert(copy._tasks[#copy._tasks].args, ({arg:gsub("~/", os.getenv("HOME") .. "/")})[1])
			else
				table.insert(copy._tasks[#copy._tasks].args, ({arg})[1])
			end
		end
		return copy
	end
end

pipeline.__tostring = function(self)
	return "pipeline: " .. tostring(self._tasks)
end


function pipeline.new(initial)
	local self = {}
	setmetatable(self, pipeline)
	
	self._capture_output = false
	self._tasks = { }
	if type(initial) == "function" then
		self._tasks[1] = {func = initial, args = {}} 
	else
		for i, task in ipairs(initial._tasks) do
			local args = {}
			for j, arg in ipairs(task.args) do
				table.insert(args, arg)
			end
			table.insert(self._tasks, { func = task.func, args = args })
		end
	end

	-- magic number; used by util.type to determine whether this is
	-- a pipeline or just another table (which can come in handy since
	-- nothing in the global environment can be nil anymore...)
	self._cmd_magic = pipeline.MAGIC_NUMBER
	
	self._copy = function()
		return pipeline.new(self)
	end

	self.out = function(file)
		return self.sub(function()
			local f = io.open(file, "w")
			if not f then print("failed to open file " .. file .. " for writing") end
			while true do
				local buffer = posix.read(0, 1024)
				if buffer == "" then break end
				f:write(buffer)
			end
			f:close()
		end)
	end

	self.sub = function(func)
		if func == nil then
			error("subshell: no function provided")
		end
		local new_pipeline = pipeline.new(func)
		local copy = self._copy()
		table.insert(copy._tasks, new_pipeline._tasks[1])
		return copy
	end

	return self
end

function pipeline:run()
	local print = function() end -- disable debug output, lol

	print(string.format("[starting %d jobs in pipeline]", #self._tasks))

	local jobs = {}
	local pipe = {fdin = nil, fdout = nil}
	for i, task in ipairs(self._tasks) do
		-- set our input to output from last process
		local oldpipe = { fdin = pipe.fdin, fdout = pipe.fdout }

		-- unless we're about to create the last process or supposed to capture the output, we need to create
		-- a pipe to redirect output to
		if i ~= #self._tasks or self._capture_output then
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

			if i ~= #self._tasks or self._capture_output then
				-- if we're not the last process, we need to redirect out output
				-- to the next process' input
				print(string.format("[%d: %d -> 1]", i, pipe.fdout))
				posix.dup2(pipe.fdout, 1)
				posix.close(pipe.fdin) -- close our copy of the read fd
			end

			-- choo choo!
			local success, result = pcall(task.func, unpack(task.args))
			
			-- note that we won't get here if the task is an external command,
			-- as the image has been replaced
			if not success then
				print("error")
				--print(string.format("\x1b[31mLua error: %s\x1b[0m", result))
				posix._exit(1)
			else
				posix._exit(0)
			end
		else
			-- if we've piped stdout -> stdin to the newly spawned child,
			-- close the parent's copies of the pipe fd's
			if i ~= 1 then
				posix.close(oldpipe.fdin)
				posix.close(oldpipe.fdout)
			end

			-- if this is the last process in the chain we need to save
			-- its return value later
			jobs[pid] = {last = (i == #self._tasks)}
		end
	end

	-- if we're supposed to capture the output of the command
	-- (for command substition), read from the last pipe
	local output = nil
	if self._capture_output then
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

	-- wait for all jobs to terminate
	local done = false
	local return_value
	while not done do
		done = true
		for p,d in pairs(jobs) do
			local rpid, stat, code = posix.wait()

			-- if this is the last process, save its exit code as our
			-- return value
			if jobs[rpid].last then
				return_value = code
			end

			-- mark as dead
			if stat == "killed" or stat == "exited" then
				print(string.format("[job %d done]", rpid))
				jobs[rpid] = nil
			end
			done = false
		end
	end

	print("[all jobs done]")

	return return_value == 0, return_value, output
end


return pipeline

