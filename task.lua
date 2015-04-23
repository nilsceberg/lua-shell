local posix = require "posix"


local pipeline = {}

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
			--os.execute(string.format("%s %s", func, encode_arguments(...)))
			posix.execp(func, {...})
			return 0
		end
	)
end

pipeline.__index = function(self, func)
	local new_pipeline = pipeline.resolve(func)
	table.insert(self._tasks, new_pipeline._tasks[1])
	return self
end

pipeline.__call = function(self, ...)
	local args = {...}
	if #args == 0 then
		run(self)
	else
		for i, arg in ipairs(args) do
			table.insert(self._tasks[#self._tasks].args, arg)
		end
		return self
	end
end

function pipeline.new(func)
	local self = {}
	setmetatable(self, pipeline)
	
	self._tasks = { {func = func, args = {}} }

	return self
end

return pipeline

