# set platform variables

# PLATFORM_OS environment variables
# WIN_CODE=windows source code
case "$PLATFORM_OS" in 
	win)		
		WIN_USER="$USER" WIN_HOME="$WIN_ROOT/Users/$WIN_USER" # for performancd assume the Windows username is the same
		WIN_PUB="$WIN_ROOT/Users/Public"; WIN_DATA="$WIN_PUB/data"
		[[ ! -d "$WIN_HOME" ]] && WIN_USER="$(cmd.exe /c set 2> /dev/null | grep '^USERNAME=' | cut -d= -f2 | tr -d '\n' | sed 's/\r//g')" WIN_HOME="$WIN_ROOT/Users/$WIN_USER"
		;;

esac

# define for all platforms for compatibility
WIN_CODE="$WIN_HOME/code"
WIN_DOC="$WIN_HOME/Documents"
WIN_UDATA="$WIN_HOME/data"	
