# common functions for Mozilla scripts

#
# extension commands
#

extensionUsage() { echot "Usage: $(ScriptName) extension dir|download|info|install|IsInstalled|ls\nExtension commands."; }
extensionArgStart() { AppInstallCheck && extensionDirValidate; }
extensionCommand() { usage; }
extensionDirCommand() { echo "$extensionDir"; }
extensionLsCommand() { profileDirValidate && cat "$profileDir/extensions.json" | jq; }

extensionDownloadCommand()
{
	local file files; IFS=$'\n' ArrayMake files "$(extensionLsCommand | jq '.addons[].path' | grep -v "null" | grep -v "@mozilla.org" | sort)"

	[[ ! $quiet ]] && printf "downloading..."
	for file in "${files[@]}"; do
		file="$(echo -E "$file" | RemoveQuotes)"
		IsPlatform win && file="$(echo -E "$file" | wtu)"
		cp "$file" . || return
		[[ ! $quiet ]] && printf "."
	done
	[[ ! $quiet ]] && echo "done"
}

#
# extension IsInstalled command
#

extensionIsInstalledUsage() { echot "Usage: $(ScriptName) extension IsInstalled FILE\Return 0 if the extensions is installed."; }
extensionIsInstalledArgStart() { AppInstallCheck; }
extensionIsInstalledArgs() {  ScriptArgGet --required "file" -- "$@" && ScriptCheckFile "$file"; }

extensionIsInstalledCommand()
{
	local id; id="$(extensionInfoIdCommand)" || return
	[[ -f "$extensionDir/$id.xpi" || -f "$extensionDirProfile/$id.xpi" ]]
}

#
# extension info commands
#

extensionInfoUsage() { echot "Usage: $(ScriptName) extension [all|id|name](all) DIR|FILE\nExtension info commands."; }
extensionInfoArgs() {  ScriptArgGet "file" -- "$@" && ScriptCheckPath "$file"; }
extensionInfoCommand() { extensionInfo "all"; }
extensionInfoAllCommand() { extensionInfo "all"; }
extensionInfoIdCommand() { extensionInfo "id"; }
extensionInfoNameCommand() { extensionInfo "name"; }

extensionInfo()
{
	local what="$1" manifest

	[[ -f "$file" ]] && { extensionManifest && RunFunction extensionInfo $what; return; }

	local files; IFS=$'\n' ArrayMake files "$(find "$file/"*.xpi |& grep -v "No such file")"	
	for file in "${files[@]}"; do
		[[ "$what" == "all" ]] && header "$(GetFileName "$file")" || printf "$(GetFileName "$file"): "
		extensionManifest || return
		RunFunction extensionInfo "$what" || return
		[[ "$what" != "all" ]] && echo
	done
} 

extensionInfoAll()
{
	echo "\
name=\"$(extensionInfoName)\"
short_name=\"$(extensionInfoShortName)\"
author=\"$(extensionInfoAuthor)\"
id=\"$(extensionInfoId)\"
description=\"$(extensionInfoDescription)\"
url=\"$(extensionInfoUrl)\""
}

extensionManifest() { manifest="$(unzip -p "$file" "manifest.json")"; }

extensionInfoGet()
{
	local value; value="$(echo "$manifest" | jq "$1" | RemoveQuotes)" || return
	[[ "$value" == @(null) ]] && value=""
	printf "$value"
}

extensionInfoAuthor() { extensionInfoGet '.author'; }

extensionInfoDescription() { local d; d="$(extensionInfoGet '.description')"; [[ "$d" == @(__MSG_extension_description__|__MSG_extensionDescription__|__MSG_extShortDesc__|__MSG_extensionDesc__|__MSG_extDescription__|__MSG_app_desc__) ]] && d=""; printf "$d"; }
extensionInfoId() { local id; id="$(extensionInfoGet '.browser_specific_settings.gecko.id')"; [[ ! $id ]] && id="$(extensionInfoGet '.applications.gecko.id')"; echo "$id"; }
extensionInfoShortName() { extensionInfoGet '.short_name'; }
extensionInfoUrl() { extensionInfoGet '.homepage_url'; }

extensionInfoName()
{
	local name; name="$(extensionInfoGet '.name')"
	[[ "$name" == @(|__MSG_appName__|__MSG_extName__|__MSG_extensionName__|__MSG_app_name__|__MSG_extension_name__) ]] && name="$(extensionInfoShortName)"
	[[ ! $name ]] && name="$(extensionInfoId)"
	printf "$name"; 
}

#
# extension install command
#

extensionInstallUsage()
{
	echot "Usage: $(ScriptName) extension install FILE
Install the extension.

	-g, --global 		install the extension for all profiles"; 
}

# extensionInstallArgStart - expects profileDirValidate to set extensionInstallArgStart
extensionInstallArgStart()
{
	AppInstallCheck && profileDirValidate && destDir="$extensionDirProfile"
}

extensionInstallArgs() {  ScriptArgGet --required "file" -- "$@" && ScriptCheckFile "$file"; }

extensionInstallOpt()
{
	case "$1" in
		-g|--global) destDir="$extensionDir";;
		*) return 1;;
	esac
}

extensionInstallCommand()
{
	local id; id="$(extensionInfoIdCommand)" || return
	local dest="$destDir/$id.xpi"

	# return if the extension is already installed
	[[ ! $force && ( -f "$dest" || -f "$extensionDir/$id.xpi" || -f "$extensionDirProfile/$id.xpi") ]] && return

	# return if the extensions is excluded
	IsDomainRestricted && [[ "$id" == @(firefoxdav@icloud.com.xpi) ]] && return

	# create the extension directory
	[[ ! -d "$destDir" ]] && { ${G}mkdir --parents "$destDir" || return; }

	# copy the extension
	cp "$file" "$dest"
}

#
# profile helper
#

# profileDirCreate - create profile directory if needed, sets profileDir
profileDirCreate()
{
	profileDirInit && [[ -d "$profileDir" ]] && return

	# start Firefox to create the profile directory	
	startCommand && sleep 2 && profileDirValidate
}

profileDirGet()
{
	# locate profiles.ini
	local p; configDirValidate || return
	p="$configDir/profiles.ini"

	# validate profiles.ini
	[[ ! -f "$p" ]] && { ScriptErrQuiet "profiles.ini does not exist in '$(FileToDesc "$p")'"; return; }

	# locate Firefox installations
	local installs="$(${G}grep '^\[Install' "$p")"
	local numInstalls="$(echo "$installs" | ${G}wc -l)"
	log2 "profileDirGet: numInstalls=$numInstalls"

	# 0 installations
	(( numInstalls == 0 )) && { ScriptErrQuiet "profileDirGet: no Firefox installations found"; return; }

	# more than 1 installation - find the installation hash, for one installation assume that one to avoid a hash lookup
	if (( numInstalls > 1 )); then
		! InPath chezmoi && { package chezmoi 1>&2 || return; }
		local check="$(GetFilePath "$program")"; IsPlatform mac && check="$program/Contents/MacOS"
		installs="[Install$(RunLog2 chezmoi execute-template '{{ mozillaInstallHash "'$check'" }}')]" || return
		log2 "profileDirGet: installation hashi for '$(FileToDesc "$check")' is '$installs'"
	fi

	# find the default profile for our installation, for 1 installation that must be our profile
	local suffix; suffix="$(${G}grep --fixed-strings --after-context=1 "$installs" "$p" | ${G}grep "^Default=" | ${G}cut -d"=" -f2 | RemoveNewline | RemoveCarriageReturn)"
	[[ ! $suffix ]] && { ScriptErr "profileDirGet: no default profile installation found for '$installs' in '$(FileToDesc "$p")'"; return; }

	# return the full profile directory
	echo "$configDir/$suffix"
}

# profileDirValidate - validate profile directory exists, sets profileDir
profileDirValidate()
{
	profileDirInit || return
	[[ ! $profileDir ]] && { ScriptErr 'could not locate the profile directory'; return; }
	[[ ! -d "$profileDir" ]] && { ScriptErr "the profile directory '$(FileToDesc "$profileDir")' does not exist"; return; }
	return 0
}

# profileExtensionsDo PRODUCT DIR
profileExtensionsDo()
{
	local product="$1" dir="$2"
	[[ "${profileArgs[0]}" != @(restore) ]] && return
	! askp 'Restore extensions' -dr n && return

	# restore extensions
	local file files; ScriptEval FindInstallFile --eval "$dir" "${globalArgs[@]}" || return
	IFS=$'\n' ArrayMake files "$(find "$file/"*.xpi |& grep -v "No such file")"
	for file in "${files[@]}"; do
		[[ ! $force ]] && firefox extension IsInstalled "$file" "${globalArgs[@]}" && continue		
		echo "Installing extensions "$($product extension info name "$file")"..."
		$product extension install "$file" "${globalArgs[@]}" || return
	done

	return 0
}

#
# helper
#

askp() { [[ $noPrompt ]] && echo "${GREEN}$1...${RESET}" || ask "$1"; }
ensureClosed() { ! isRunningCommand && return; closeCommand && sleep 2; }

IsFirefox() { [[ "$program" =~ firefox ]]; }
IsThunderbird() { [[ "$program" =~ thunderbird ]]; }

# configDirValidate - validate configuration directory
configDirValidate()
{
	[[ ! $configDir ]] && { ScriptErr 'could not locate the configuration directory'; return; }
	[[ ! -d "$configDir" ]] && { ScriptErr "the configuration directory '$(FileToDesc "$configDir")' does not exist"; return; }
	return 0
}

# extensionDirValidate - validate configuration directory
extensionDirValidate()
{
	[[ ! $extensionDir ]] && { ScriptErr 'could not locate the extension directory'; return; }
	[[ ! -d "$extensionDir" ]] && { ScriptErr "the extension directory '$(FileToDesc "$extensionDir")' does not exist"; return; }
	return 0
}
