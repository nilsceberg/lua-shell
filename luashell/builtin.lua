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
	local copy = pipeline._copy()
	copy._capture_output = true
	return ({copy:run()})[2]
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


return module

