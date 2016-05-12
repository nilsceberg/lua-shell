lua-shell
=========

**lua-shell** (working title) is an attempt at harnessing the power of Lua for use as a
Unix shell. Thus, the goals of the project are:

* To provide an intuitive interface to external programs, including system utilities such as `ls` and `sudo` as well as other CLI tools, in a consistent manner.
* To provide facilities for creating command pipelines in order to take advantage of the Unix philosophy of combining small, specialized programs to complete a complex task.
* To provide an improved REPL, compared to the default one of Lua's interactive interpreter.

The project is still very much a work in progress and is not suitable for practical usage.

Examples
--------

#### Demo
The following example script demonstrates a couple of the features -- external commands, integration with Lua functionality, subshells, command substitution and stdout redirection -- provided by lua-shell:

```lua
function get_ls_args()
	return "-l", "~/projects/lua-shell/"
end

function formatter(prefix) print(prefix .. io.read("*a")) end

ls(get_ls_args())                     -- retrieve file list
  .grep "READ"                        -- filter to find line including 'READ'
  .grep "-oP" "[^ ]+$"                -- filename only
  .sub(formatter) "File found: "      -- add label with our formatter function as a subshell
  .out "/tmp/luashelltest"()          -- redirect to /tmp/luashelltest

myVar = cs(cat "/tmp/luashelltest")   -- command substitution to put contents of file into variable

echo(myVar)()                         -- echo variable with external program
```

This is the equivalent code in the traditional shell scripting syntax:

```bash
function get_ls_args
{
	echo "-l ~/projects/lua-shell"
}

function formatter { echo "$1"$(cat); }

ls $(get_ls_args) |
  grep "READ" |
  grep -oP "[^ ]+$" |
  formatter "File found: " >
  /tmp/luashelltest

myVar=$(cat /tmp/luashelltest)

echo $myVar
```

#### rc file
Upon starting the shell, the file `~/.lushrc` is automatically executed. This file can be used to set up aliases,
settings the prompt and doing other initialization work, just like `.bashrc` and equivalents. Here is an example `.lushrc` file:

```lua
-- Include luaposix modules and set some global variables.
posix = require("posix")
posix_uts = require("posix.sys.utsname")
utsname = posix_uts.uname()
HOST=utsname.nodename
HOME=os.getenv("HOME")
USER=posix.getlogin()


-- Set up aliases.
ls=ls "--color=always"

-- Set up a table 'git' with a metatable to
-- let us run commands like 'git.status' instead of 'git "status"'.
local _git = git
git = {}
setmetatable(git,
{
	__index = function(t, func) return _git(func) end
})

-- Utility function to reload this file.
function rrc()
	dofile(HOME .. "/.lushrc")
	print("RC file reloaded.")
end

-- Make the prompt path a little prettier by substituting
-- the home part of the path with '~'.
function make_pretty_path()
	return posix.getcwd():gsub(HOME, "~")
end

-- Extract the currently checked out branch of the Git repository we're in.
-- stderr is simply redirected to stdout so that, in case we're not in a Git repository,
-- the error message is just piped to grep but won't match.
function get_git_branch()
	branch = cs(err(git.branch) . grep "-oP" "\\* .+$" . grep "-oP" "[^* ]+")
	if branch == "" then
		return ""
	else
		return string.format(" [%s]", branch)
	end
end

-- Actually set the prompt. This function gets called each time the prompt is printed.
-- Escape sequences are ANSI colours.
function settings.prompt()
	return string.format("\x01\x1b[32;1m\x02[%s@%s:%s]%s [%s]\n\x01\x1b[31;1m\x02$ \x01\x1b[0m\x02",
			USER, HOST, make_pretty_path(), get_git_branch(), os.date("%H:%M:%S"))
end

```

License
-------
See [LICENSE.md](LICENSE.md).
