local pipeline = require "luashell.pipeline"

local module = {}

module._type = type

function module.type(object)
	return module._type(object) == "table"
		and object._cmd_magic == pipeline.MAGIC_NUMBER and "pipeline"
		or module._type(object)
end

return module
