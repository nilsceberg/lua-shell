local posix = require "posix"

local pipeline = require "pipeline"

function sub(func)
	if func == nil then
		error("subshell: no function provided")
	end
	return pipeline.new(func)
end

function cs(pipeline)
	local copy = pipeline._copy()
	copy._capture_output = true
	return ({run(copy)})[2]
end

cd = function(path)
	if not path then
		path = HOME
	end
	posix.chdir(path)
	return nil
end

