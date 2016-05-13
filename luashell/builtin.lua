local posix = require "posix"
local pipeline = require "luashell.pipeline"

local module = {}


function module.sub(func)
	if func == nil then
		error("subshell: no function provided")
	end
	return pipeline.new(func)
end

function module.cs(pipeline)
	assert(type(pipeline) == "pipeline")

	local copy = pipeline._copy()
	copy._capture_output = true

	local success, retval, output = copy:run()
	return output, retval
end

function module.cd(path)
	if not path then
		path = os.getenv("HOME")
	else
		path = path:gsub("~/", os.getenv("HOME") .. "/")
	end
	posix.chdir(path)
	return nil
end

function module.err(pipeline)
	return module.sub(function()
		posix.dup2(1, 2)
		pipeline()
	end)
end

module.here = {}
setmetatable(module.here,
{
	__index = function(self, name)
		return pipeline.resolve("./" .. name)
	end,
	__call = function(self, name)
		return pipeline.resolve("./" .. name)
	end
})

function module.exec(file, ...)
	return pipeline.resolve(file)
end



return module

