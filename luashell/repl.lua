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


function module:run_once()
	local command = ""
	local line = readline.readline(self.settings.prompt()) --io.read("*line")
	while line:match("\\$") do
		--io.write(module.prompt_continue())
		command = command .. line:match("(.+)\\$") .. "\n"
		line = readline.readline(self.settings.prompt_continue()) --io.read("*line")
	end
	command = command .. line

	-- first, try returning whatever the command results in
	local func, err = load(string.format("return (%s)", command), "shell", "t")
	if func ~= nil then
		local status, result = pcall(func)
		
		if not status then
			-- an error occurred; print message
			print(string.format("\x1b[31m%s\x1b[0m", result))
		else
			-- we're good!
			-- handle return value
			
			-- if it's a command pipeline or a function, execute it
			if type(result) == "function" or (type(result) == "table" and result._cmd_magic == pipeline.MAGIC_NUMBER) then
				local status, result = pcall(result)
				if not status then
					print(string.format("\x1b[31m%s\x1b[0m", result))
				end
			elseif result then
				-- otherwise, just print it
				print(string.format("[%s]", tostring(result)))
			end
		end
	else
		-- if that is syntactically wrong, try without the return
		func = load(command, "shell", "t")

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

