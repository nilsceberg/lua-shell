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
	local new_pipeline = pipeline.resolve(func)

	local copy = self._copy()
	table.insert(copy._tasks, new_pipeline._tasks[1])
	return copy
end

pipeline.__call = function(self, ...)
	local args = {...}
	if #args == 0 then
		return run(self)
	else
		local copy = self._copy()
		for i, arg in ipairs(args) do
			table.insert(copy._tasks[#copy._tasks].args, ({arg:gsub("~/", os.getenv("HOME") .. "/")})[1])
		end
		return copy
	end
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

	self._cmd_magic = pipeline.MAGIC_NUMBER -- magic number
	
	self._copy = function()
		return pipeline.new(self)
	end

	return self
end

return pipeline

