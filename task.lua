local task = {}

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

function task.resolve(func, args)
	return task.new(
		function()
			os.execute(string.format("%s %s", func, encode_arguments(unpack(args))))
			return 0
		end
	)
end

task.__index = function(tab, func)
	if func == "_next" or func == "_prev" then return nil end

	return function(self, ...)
		local args = {...}
		local new_task = task.resolve(func, args)
		self._next = new_task
		new_task._prev = self
		return new_task
	end
end

function task.new(func)
	local self = {}
	setmetatable(self, task)

	self._func = func

	return self
end

return task

