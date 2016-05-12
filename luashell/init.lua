local posix = require "posix"
local readline = require "readline"

local builtin = require "luashell.builtin"
local pipeline = require "luashell.pipeline"
local version = require "luashell.version"
local util = require "luashell.util"

local module = {}


function module.pollute(t)
	local old_table = {}
	for k,v in pairs(t) do
		old_table[k] = v
	end

	-- set up indexing meta table
	setmetatable(t,
	{
		__index = function(tab, func)
			return pipeline.resolve(func)
		end,
		__old = old_table
	})
	
	-- load builtins
	for k,v in pairs(builtin) do
		t[k] = v
	end

	-- load utils
	for k,v in pairs(util) do
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

