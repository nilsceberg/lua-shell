local module = {}
module.__index = module

local pipeline = require "luashell.pipeline"

local readline = require "readline"


function module.new(settings)
	local self = {}
	setmetatable(self, module)
	
	self.settings = settings
	self.return_value = 0

	-- set up readline
	readline.set_options{ keeplines=1000, histfile='~/.module_history' }

	return self
end

local function is_incomplete(expression)
	-- if a return statement with the expression produces no error, we
	-- consider the expression complete
	local _, err =
		load(string.format("return %s", expression), "shell", "t")
	if err == nil then return false end

	-- otherwise, the expression is incomplete if it results in an error
	-- ending in "<eof>"
	local _, err = load(expression, "shell", "t")
	return err and err:match("<eof>$") or false
end

-- returns the first argument on its own and the rest in a table
local function return_groups(...)
	local t = {...}
	return table.remove(t, 1), t
end

function module:run_once()
	-- prompt for expression until it's syntactically complete
	local expression = readline.readline(self.settings.prompt()) .. "\n"
	while is_incomplete(expression) do
		expression =
			expression .. readline.readline(self.settings.prompt_continue())
			.. "\n"
	end

	-- allow leading = to be replaced with 'return' like the standalone Lua
	-- REPL
	expression = expression:gsub("^=", "return ")

	-- first, try returning whatever the expression evaluates to
	local func, err =
		load(string.format("return %s", expression), "shell", "t")

	if func ~= nil then
		local status, result = return_groups(pcall(func))
		
		if not status then
			-- an error occurred; print message
			print(string.format("\x1b[31m%s\x1b[0m", result[1]))
		else
			-- we're good!
			-- handle return value
			
			-- if it's a function or a pipeline, execute it and
			-- replace result with its return value
			if type(result[1]) == "function"
					or type(result[1]) == "pipeline" then
				local is_pipeline = type(result[1]) == "pipeline"
				status, result = return_groups(pcall(result[1]))

				-- print error
				if not status then
					print(string.format("\x1b[31m%s\x1b[0m", result[1]))
				end

				-- if it's a pipeline, update the return value
				if is_pipeline then self.return_value = result[2] end
			end

			-- return result
			return result
		end
	else
		-- if that is syntactically wrong, try without the return
		local func, err = load(expression, "shell", "t")

		-- if it still results in an error, the fault is the user's,
		-- so print the error message
		if not func then
			print(string.format("\x1b[31m%s\x1b[0m", err))
		else
			-- if we're good, run the command
			local status, result = return_groups(pcall(func))

			-- check for errors and print message
			if not status then
				print(string.format("\x1b[31m%s\x1b[0m", result[1]))
			end

			return result
		end
	end
end

function module:run()
	self.running = true
	while self.running do
		self:run_once()
	end
end

return module

