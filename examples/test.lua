function get_ls_args()
	return "-l", "~/projects/lua-shell/"
end

function formatter(prefix) print(prefix .. io.read("*a")) end

ls(get_ls_args())                   -- retrieve file list
	.grep "READ"                    -- filter to find line including 'READ'
	.grep "-oP" "[^ ]+$"            -- filename only
	.sub(formatter) "File found: "  -- add label with our formatter function
	.out "/tmp/luashelltest"()      -- redirect to /tmp/luashelltest

fileString = cs(cat "/tmp/luashelltest")   -- command substitution to put contents of file into variable

echo(fileString)()                         -- echo variable with external program

--[[
 == bash equivalent == 

function get_ls_args
{
	echo "-l ~/projects/lua-shell"
}

function formatter { echo "$1" $(cat); }

ls $(get_ls_args) | grep "READ" | formatter "File found:" > /tmp/luashelltest
fileString=$(cat /tmp/luashelltest)
echo $fileString

]]

