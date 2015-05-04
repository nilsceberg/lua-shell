function get_ls_args()
	return "-l", "~/sts/io/level11/"
end

function formatter(prefix) print(prefix .. io.read("*a")) end

ls(get_ls_args()):grep("md5.c"):sub(formatter, "FIle found:"):out("/tmp/luashelltest")()
RED = cs(cat "/tmp/luashelltest")
echo(RED)

--[[
 == bash equivalent == 

function get_ls_args
{
	echo "-l ~/sts/io/level11/"
}

function formatter { echo "$1" $(cat); }

ls $(get_ls_args) | grep "md5.c" | formatter "File found:" > /tmp/luashelltest
RED=$(cat /tmp/luashelltest)
echo $RED

]]

