lua-shell
=========

**lua-shell** (working title) is an attempt at harnessing the power of Lua for use as a
Unix shell. Thus, the goals of the project are:

* To provide an intuitive interface to external programs, including system utilities such as `ls` and `sudo` as well as other CLI tools, in a consistent manner.
* To provide facilities for creating command pipelines in order to take advantage of the Unix philosophy of combining small, specialized programs to complete a complex task.
* To provide an improved REPL, compared to the default one of Lua's interactive interpreter.


Examples
--------

The following example script demonstrates a couple of the features -- external commands, integration with Lua functionality, subshells, command substitution and stdout redirection -- provided by lua-shell:

```lua
function get_ls_args()
	return "-l", "~/projects/lua-shell/"
end

function formatter(prefix) print(prefix .. io.read("*a")) end

ls(get_ls_args())                     -- retrieve file list
  .grep "READ"                        -- filter to find line including 'READ'
  .grep "-oP" "[^ ]+$"                -- filename only
  .sub(formatter) "File found: "      -- add label with our formatter function
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

License
-------
See [LICENSE.md](LICENSE.md).
