#!/bin/lua

require"luashell.init".globalize()

echo ("return \"" .. ({...})[1] .. "\"").out("luashell/version.lua")()

