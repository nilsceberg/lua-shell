local posix = require "posix"
local readline = require "readline"

local builtin = require "luashell.builtin"
local pipeline = require "luashell.pipeline"
local version = require "luashell.version"

local module = {}


function module.pollute(t)
	-- set up indexing meta table
	setmetatable(t,
	{
		__index = function(tab, func)
			return pipeline.resolve(func)
		end
	})
	
	-- load builtins
	for k,v in pairs(builtin) do
		t[k] = v
	end
end

function module.globalize()
	-- pollute _G to allow for stuff like
	-- calling running system commands like Lua functions
	module.pollute(_G)
end

function module.version()
	return version
end


return module

