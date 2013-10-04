:clr
if not "$@search[ClrVer]" == "" return 1
ClrVer
echo Runtime versions used by active processes:
ClrVer -all
return 0

:IsNet

gosub GetFile

# CorFlags requires the .NET framework 2.0 runtime
iff not IsFile "$frameworkDir/v2.0.50727/ngen.exe" then
	return 1
endiff

CorFlags "$file" >& nul:
echo $@if[$? == 0,1,0]

return 0

# Test using 
:target

gosub GetNetFile

pe=$@word[2,$@ExecStr[CorFlags "$file" | egrep "PE        :"]]
Force32Bit=$@word[2,$@ExecStr[CorFlags "$file" | egrep "32BIT     :"]]

iff "$pe" == "PE32" .and. "$Force32Bit" == "0" then
  echo any
elseiff "$pe" == "PE32" .and. "$Force32Bit" == "1" then
	echo x86
elseiff "$pe" == "PE32+" then
	echo x64
endiff

return

:RuntimeVersion

gosub GetNetFile

echo $@word[2,$@ExecStr[CorFlags "$file" | egrep "Version   :"]]

return 0

:version

gosub GetNetFile

# The .NET version of the file is the version of the first dependency
echo $@word["=",1,$@word[1,$@ExecStr[NetDepends "$file"]]]

return

:name

gosub GetNetFile

# The .NET name of the file is the name of the first dependency
echo $@ExecStr[NetDepends "$file"]

return

# Determine the framework required version by checking for references to framework assemblies.   This is valid as long 
# as there are no other assembly references with the same version as the .NET Framrwork.
:FrameworkVersion

gosub GetNetFile
if $# != 0 goto usage

DependencyFile=$@unique[$temp]

# Get the dependencies
NetDepends "$file" >& "$DependencyFile"
iff $? != 0 then
	echo Unable to determine the dependencies for $file. 1>&2
	return 1
endiff

# Check the dependencies 
for /l $i in (0,1,$@eval[ $@words[$frameworkFileVersion] - 1]) (
	
	FrameworkVersion=$@word[$i,$frameworkFileVersion]
	AssemblyVersion=$@word[$i,$assemblyVersions]
	
	egrep -i Version=$AssemblyVersion "$DependencyFile" >& nul:
	iff $? == 0 then
		gosub FrameworkVersionCleanup
		echo $version
		quit 0
	endiff
)

echo unknown
gosub FrameworkVersionCleanup

return 1

:FrameworkVersionCleanup
call DelFile "$DependencyFile"
return

# Get argument from the command line that must be a file
:GetFile

file=$@UnQuote[$1]
iff not IsFile "$file" then
	echo Could not find $file.  1>&2
	quit 1
endiff

shift
if $# != 0 goto usage

return

# Get argument from the command line that must be a .NET file
:GetNetFile

gosub GetFile

iff $@IsNet[$file] != 1 then
	echo $file is not a .NET executable or assembly. 1>&2
	quit 1
endiff

return

:test

p=$PublicData/install/Microsoft/.NET/test

echo Testing runtime and framework version...
for $file in ($p/version/*) (
	echo $@name[$file]: runtime $@NetRuntimeVersion[$file] framework $@NetFrameworkVersion[$file]
)

echo.
echo Testing target...
for $file in ($p/target/*) (
	echo $@name[$file]: target $@NetTarget[$file]
)

return

:register

for assembly in ($$) (
	echos Registring $@Name[$assembly]... 
	"$gacUtil" /nologo /if $@quote[$assembly]
)

return
