########################################
# Misc
########################################

BEGIN {
	CommonInit()
}

END {
	SystemDeferFlush()
}

function CommonInit()
{
	CommonConstants()
	
	AWK_Program = ARGV[0]
}

function CommonConstants()
{
   TRUE = -1
   FALSE = 0
}

function PipeMake(cmd)
{
	if (AWK_Program == "awk16" || AWK_Program == "awk32")
           return(gget("bin") "\\tcc.exe /c (" cmd ")")
	else
	   return("(" cmd ")")
}

function RunCmd(cmd)
{
	cmd | getline result
	close(cmd)
	return(result)
}

# gset()
#
# Sets variables in the global environment.  Windows does not support the setting 
# of gloval environment variables directly so the fixes to do this are version dependent.
function gset(var, value)
{
	# Set the variable in our environment so we can access it using gget.
	ENVIRON[toupper(var)] = value

	# Defer the change to the global environment until later.
    if (gget("os") == "Windows_NT")
		# TODO: update the registry
		SystemDefer("set " var "=" value)
	else
		SystemDefer("winset.exe " var "=" value)
}

# Set aliases in an alias file.
function AliasDefer(AliasFileName)
{
  SystemDefer("if exist " AliasFileName " alias/r " AliasFileName)  
}

# Run a 4dos batch file.
function BatchDefer(BatchFileName)
{ 
  SystemDefer("if exist " BatchFileName " " BatchFileName)  
}

# Run a 4dos system command, but defer it's processing until awk exists.
# This minimizes calls to the os for some system calls.
function SystemDefer(cmd)
{
	SystemDeferA[++SystemDeferIndex] = cmd
}

# Log 
function SystemDeferFlush(   i, file)
{
	file = gget("temp") "\\gset.btm"
	StartLog(file)
	ToLog("@echo off")

	for (i=1 ; i<=SystemDeferIndex ; ++i) {
		#ToLog("echo CMD: " SystemDeferA[i])
		ToLog(SystemDeferA[i])
	}
	
	close(file)
	system(PipeMake(file))
	RemoveFile(file)
}

function gget(var)
{
	return(ENVIRON[toupper(var)])
}

function DriveConnectDefer(DriveLetter, unc)
{
	if (gget("os") == "Windows_NT") 
		SystemDefer("if not IsDir " DriveLetter "\\ net use " DriveLetter " " unc " /persistent:yes")
	else
		SystemDefer("if not IsDir " DriveLetter "\\ net use " DriveLetter " " unc)
}

########################################
# Files and Directories
########################################

function DirExistP(DirName   , result)
{
 	cmd = PipeMake("iff IsDir " DirName " then & echo -1 & else & echo 0 & EndIff")
	cmd | getline result
	close(cmd)

	return(result == -1 ? TRUE : FALSE)
}

function FileExistP(FileName   , result)
{
	cmd = PipeMake("iff Exist " FileName " then & echo -1 & else & echo 0 & EndIff")
	cmd | getline result
	close(cmd)

	return(result == -1 ? TRUE : FALSE)
}

function RemoveFile(file)
{
   return(system(PipeMake("del /q " file)));
}

function CopyFile(src, dest)
{
   return(system("copy /q " src " " dest));
}

function CombineFile(src,dest)
{
   gsub(/ /, "+", src);
   return(system("copy /q /b " src " " dest));
}

function FileList(FileSpec, SubDirectories   , result)
{
   if (SubDirectories == "") SubDirectories = FALSE

   cmd = PipeMake("dir /b /f /ou " (SubDirectories ? "/s " : "") FileSpec)
   while (cmd | getline)
      result = result " " $0
   close(cmd)
   return(ltrim(result))
}

########################################
# Arguments
########################################

# Return TRUE if s is in the argument list, and FALSE otherwise.
function ArgFind(s)
{
   for (i in ARGV)
      if (tolower(ARGV[i]) == s) {
         ArgvShift(i)
         return(TRUE)
      }

   return(FALSE)
}

# Return the ShiftAt element in ARGV and shift the remaining elements left
# in the ARGV array.
function ArgvShift(ShiftAt,   result, i)
{
   # Make sure we have enough arguments.
   if (ARGC == 0) {
      Usage()
      exit 1
    }

   # If the argument to shift at is not given assume it to be 1.
   if (ShiftAt == "") ShiftAt = 1

   result = ARGV[ShiftAt]
   for (i = (ShiftAt + 1) ; i <= ARGC ; ++i)
      ARGV[i - 1] = ARGV[i]
   delete ARGV[ARGC--]
   return(result)
}

########################################
# String
########################################

function trim(s)
{
   return ltrim(rtrim(s))
}

function ltrim(s)
{
   sub(/^ */, "", s)
   return s
}

function rtrim(s)
{
   sub(/ *$/, "", s)
   return s
}

# Repeat string s n times.
function RepeatString(s, n   , i, result)
{
   for (i = 0 ; i < n ; ++i)
      result = result s
   return result
}

# Return TRUE if s is the empty string, "".
function EmptyStr(s)
{
   return (s == "")
}

function RemoveParens(s   , orig)
{
   orig = s

   if (sub(/^\(/, "", s) && sub(/\)$/, "", s))
      return s
   else
      return orig
}

function RemoveCommas(s)
{
   gsub(/,/, "", s)
   return(s)
}

########################################
# Numeric
########################################

function IsInteger(n)
{
   return match(RemoveCommas(n), /^[0-9]+$/)
}

function IsNumber(n)
{
	n = NegToFront(RemoveCommas(RemoveParens(n)))
	return(match(n, /^-?[0-9]+(\.[0-9]*)?$/) || match(n, /^-?\.[0-9]+$/))
}

# Remove parens around negative numbers and add - prefix.
function ParenToNeg(n)
{
   if (substr(n, 1, 1) == "(" && substr(n, length(n), 1) == ")")
      return("-" substr(n, 2, length(n) - 1))
   else
      return(n)
}

# Move the negative sign to the front of the number if needed.
function NegToFront(n)
{
	if (substr(n, length(n), 1) == "-")
		return("-" substr(n, 1, length(n) - 1))
	else
		return(n)
}

function max(a, b)
{
   return (a > b ? a : b)
}

function min(a, b)
{
   return (a > b ? b : a)
}

########################################
# Array
########################################

function ArraySize(   a, i, count)
{
   count = 0
   for (i in a) ++count
   return count
}

########################################
# Error 
########################################

function ErrorGen(s)
{
   print "ERROR: " s > "/dev/stderr"
   exit 1
}

########################################
# Log
########################################

function StartLog(FileName)
{
   LogFileName = FileName
   printf "" > LogFileName
}

function ToScreen(s)
{
   print s
}

function ToLog(s)
{
   print s >> LogFileName
}

function ToBoth(s)
{
   print s
   print s >> LogFileName
}

########################################
# Postscript
########################################

function PSpageCount(FileName   , result)
{
   while (getline < FileName)
      if (($0 == "EJ RS") || ($0 == "showpage")) ++result
   return(result)
}
