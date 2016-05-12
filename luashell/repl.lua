local module = {}
module.__index = module

local pipeline = require "luashell.pipeline"

local readline = require "readline"


function module.new(settings)
	local self = {}
	setmetatable(self, module)
	
	self.settings = settings

	-- set up readline
	readline.set_options{ keeplines=1000, histfile='~/.module_history' }

	return self
end

local function is_incomplete(expression)
	-- if a return statement with the expression produces no error, we
	-- consider the expression complete
	local _, err =
		load(string.format("return (%s)", expression), "shell", "t")
	if err == nil then return false end

	-- otherwise, the expression is incomplete if it results in an error
	-- ending in "<eof>"
	local _, err = load(expression, "shell", "t")
	return err and err:match("<eof>$") or false
end

function module:run_once()
	-- prompt for expression until it's syntactically complete
	local expression = readline.readline(self.settings.prompt()) .. "\n"
	while is_incomplete(expression) do
		expression =
			expression .. readline.readline(self.settings.prompt_continue())
			.. "\n"
	end

	-- first, try returning whatever the expression evaluates to
	local func, err = load(string.format("return (%s)", expression), "shell", "t")
	if func ~= nil then
		local status, result = pcall(func)
		
		if not status then
			-- an error occurred; print message
			print(string.format("\x1b[31m%s\x1b[0m", result))
		else
			-- we're good!
			-- handle return value
			
			-- if it's a command pipeline or a function, execute it and
			-- replace result with its return value
			if type(result) == "function" or (type(result) == "pipeline") then
				status, result = pcall(result)

				-- print error and skip result printing
				if not status then
					print(string.format("\x1b[31m%s\x1b[0m", result))
					return
				end
			end

			-- print return value
			if result then
				print(string.format("[%s]", tostring(result)))
			end
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
			local status, result = pcall(func)

			-- check for errors and print message
			if not status then
				print(string.format("\x1b[31m%s\x1b[0m", result))
			end
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

