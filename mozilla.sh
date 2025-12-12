# common functions for Mozilla scripts

#
# extension commands
#

extensionUsage() { echot "Usage: $(ScriptName) extension dir|download|info|install|IsInstalled|ls\nExtension commands."; }
extensionArgStart() { AppInstallCheck; }
extensionCommand() { usage; }
extensionDirCommand() { [[ -d "$extensionDir" ]] && echo "$extensionDir"; }
extensionLsCommand() { cat "$profileDir/extensions.json" | jq; }

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
extensionIsInstalledArgs() {  ScriptArgGet "file" -- "$@" && ScriptCheckFile "$file"; }

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

extensionInstallArgStart() { destDir="$extensionDirProfile"; AppInstallCheck; }
extensionInstallArgs() {  ScriptArgGet "file" -- "$@" && ScriptCheckFile "$file"; }

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

# profileDirCreate - create profile dir if it does not exist, sets profileDir
profileDirCreate()
{
	[[ -d "$profileDir" ]] && return

	# start Firefox to create the profile directory	
	startCommand && sleep 2 && profileDirInit && profileDirValidate
}

profileDirGet()
{
	local p="$configDir/profiles.ini" profileSuffix
	[[ -f "$p" ]] && profileSuffix="$(cat "$p" | ${G}grep '^Default=Profiles' | ${G}head -1 | cut -d"=" -f2 | RemoveNewline | RemoveCarriageReturn)" && echo "$configDir/$profileSuffix"
}

profileDirValidate()
{
	[[ -d "$profileDir" ]] && return
	ScriptErr "the profile directory '$profileDir' does not exist"
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
