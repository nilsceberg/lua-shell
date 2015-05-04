#!/bin/lua

posix = require "posix"
local readline = require "readline"

local builtin = require "luashell.builtin"
local pipeline = require "luashell.pipeline"


-- setup __index on _G to allow for
-- calling running system commands like lua functions
setmetatable(_G,
{
	__index = function(tab, func)
		return pipeline.resolve(func)
	end
})

