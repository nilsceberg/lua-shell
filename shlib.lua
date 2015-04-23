local posix = require "posix"

local pipeline = require "pipeline"

function sub(func)
	if func == nil then
		error("subshell: no function provided")
	end
	return pipeline.new(func)
end

cd = function(path)
	if not path then
		path = HOME
	end
	posix.chdir(path)
	return nil
end

