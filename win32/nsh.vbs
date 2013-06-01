'''<summary>
'''nsh.vbs version 1.42: Script to compile and run a .net EXE from one or more .NET source files (.cs / .vb / .js)
'''</summary>
'''
'''<remarks>
''' Usage:
'''   nsh sourcefilename.cs
'''     Compiles and runs only specified sourcefilename. Looks in currdir first, then in nsh-sourcedir
'''   nsh *.cs
'''     Compiles every *.cs sourcefile found in currdir into one .exe, then runs
'''   nsh * arg1 arg2
'''     Compiles every .net sourcefile found in currdir into one .exe, then runs passing in cmd-line args arg1, arg2
'''   nsh **
'''     Compiles and every .net sourcefile found in currdir and any subdirs into one .exe, then runs
'''
''' Implementation notes:
'''     x This nsh.vbs script may be copied and renamed to be paired with a "codebehind" .cs, .vb or .js file.
'''     x .exe is created-in and run-from tempdir
'''     x .exe working dir is the start-up working dir
'''     x if script-dir includes "nsh.vbs", then the startup working dir is preserved. Otherwise, the working-dir is set to be the script dir.
'''     x If there is a sourcefilename.config file found in the same dir as sourcefile.*, it is copied to tempdir\sourcefilename.exe.config before the run
'''     x If there is a sourcefilename.configscc file found in the same dir as sourcefile.*, it is used to pull the latest sourcefile.cs/vb/js (and sourcefile.config if it exists in scc).
'''         x The .configscc file is copied to the target-exec-dir (to sourcefilename.exe.configscc), in a similar manner to the optional .config file
'''         x The sourcefile.cs/vb/js must already exist in the filesystem for this to work.
'''         x The sourcefile.cs/vb/js and sourcefile.config must have R/O attrib set to be updated from SCC. If R/O attrib not set, the scc get-latest is skipped.
'''         x Currently only sourcesafe scc provider is supported.
''' 
'''     x /reference: is searched for in first comment line(s) of output-named sourcefile, if found is passed to compiler
'''         x If first listed reference is not found in work-dir, then nsh-dir is tried. 
'''         x Any subsequent filename-only references are prefixed with the path where the first ref was found.
'''         x All reference dlls and any same-dir dependencies they have are copied to the tempdir where the exe is run from.
'''     
'''         Example:
'''             <code>
'''                 // /reference:mylib1.dll,mylib2.dll
'''                 using System;
'''                 . . .
'''             </code>
'''             
'''             if mylib1.dll found in working-dir, that dir used for both mylib1, mylib2; otherwise nsh-home-dir is used.
''' 
'''     x Reserved int return code ReservedNshNoMsgExitCode results in no echo-msg by nsh.
'''
''' Dependencies:
'''     x .NET Framework 1.0 or higher
'''     x WSH 5.1 or higher
'''     x cmd.exe in %PATH%
'''     x xcopy.exe in %PATH%
'''     x MSXML2, if .config and/or .configscc file present
'''     x SourceSafe COM objects, if .configscc file present
'''
'''</remarks>
'''
'''<returns retval=0>Success</returns>
'''<returns>(non-0 retval): Failure</returns>
'''
'''<author>buc@acm.org
'''</author>
'TODO: Copy only diff-timestamp ref-dlls 
'TODO: Always recompile if newer ref-dlls
'TODO: If wildcard look for file having Main()
'TODO: Support heterogeneous mix of languages when using wildcard
option explicit

const debugMode = false 'set to true to get wsh line-# errors when debugging

'BEGIN commonly-changed params
const EnableCscriptWindowFromWscript = true 'Change to false to hide the cscript window from wscript
'END   commonly-changed params

const NshMainScriptBaseName = "nsh"
const GeneralError = &h80040200
const ReservedNshNoMsgExitCode = 249
const ReservedNshNoMsgExitString = "**m_NoMsgOptionSet=true**"
dim m_NoMsgOptionSet: m_NoMsgOptionSet = false
dim m_fso: set m_fso = CreateObject("scripting.filesystemobject")
dim m_wshell: set m_wshell = CreateObject("wscript.shell")
dim m_outputExit: set m_outputExit = new OutputExit
dim m_toolUtilsObj: set m_toolUtilsObj = new ToolUtils
dim m_dotNetObj: set m_dotNetObj = new DotNetUtils
dim m_tempDirToUse

if not debugMode then
    err.Clear
    on error resume next
end if

dim outCapture: outCapture = Main()

dim msg
dim ret
if err.number <> 0 then '? ERR
    ret = 1
    if m_outputExit.IsWScriptContext() then
        msg = "FAILURE." & vbcrlf & vbcrlf & GetOneScreenfull(err.Description)
    else
        msg = "FAILURE." & vbcrlf & vbcrlf & err.Description
    end if      
    on error goto 0
    m_outputExit.WriteLine msg
    m_outputExit.Quit ret
else
    on error goto 0
    ret = 0
    msg = "SUCCESS."
    if m_NoMsgOptionSet then
        if m_outputExit.IsWScriptContext() then
            m_outputExit.Quit ret 'Quit silently when NoMsgOptionSet
        else
            wscript.echo ReservedNshNoMsgExitString
        end if          
    elseif m_outputExit.IsWScriptContext() then
        if InStr(outCapture, ReservedNshNoMsgExitString) >= 1 then
            m_outputExit.Quit ret 'Quit silently when NoMsgOptionSet
        else        
            msg = msg & vbcrlf & vbcrlf & GetOneScreenfull(outCapture)
            m_outputExit.WriteLine msg
            m_outputExit.Quit ret 
        end if          
    else        
        m_outputExit.Quit ret 'Quit silently on cscript success
    end if
end if

function Main()
    dim ret

    SetWorkingDirIfNec
    
    if m_outputExit.IsWScriptContext and EnableCscriptWindowFromWscript then  
        'Launch cscript window (to show progress on long-running processes)
        dim process: set process = new SyncProcess
        process.Exec "cscript.exe", _
                """" &  wscript.ScriptFullName & """ " & _
                GetQuotedArgs(), _
                true, true, 0 'true = failOnErr, true = echoDuring
        ret = StripWshHeader(process.OutCapture)
        Main = ret
        exit function
    end if
    
    'Parse cmd-line args
    dim startAppParamIndex
    dim params: Set params = wscript.Arguments
    dim argsStr: argsStr = "args supported: file(s) [arg1] [argn]"
    if IsNshMain() then
        If params.Count = 0 Then
            err.Raise GeneralError, "Main", "Bad cmd-line syntax. " & argsStr
        end if        
        dim fileSpec: fileSpec = params(0)
        startAppParamIndex = 1
    else
        fileSpec = DeriveSourceFileFromScriptName()
        startAppParamIndex = 0
    end if
            
    dim targetCmdLine: targetCmdLine = ""
    dim i
    for i = startAppParamIndex to params.Count - 1
        dim arg: arg = GetQuotedArg(params(i) )
        targetCmdLine = targetCmdLine & arg & " "
    next
    
    'Compile
    
    dim recursePrefix: recursePrefix = "" 'default
    dim compileFileSpec: compileFileSpec = fileSpec 'default
    dim ix: ix = InStr(filespec, "**")
    if ix >= 1 then
        compileFileSpec = mid(fileSpec, 1, ix -1) & mid(fileSpec, ix + 1)  'Strip the leading *
        recursePrefix = "/recurse:"
    end if
    
    dim addlCompilerCmdLineArgs
    dim mainSourceFile
    dim useCachedBin
    dim assemblyPath: assemblyPath = GetAssemblyPath(compileFileSpec, mainSourceFile, addlCompilerCmdLineArgs, useCachedBin)

    dim compilerExeName: compilerExeName = m_fso.GetExtensionName(mainSourceFile) & "c.exe"

	if not useCachedBin then
		DeleteFileIfExists assemblyPath
		DeleteFileIfExists m_fso.BuildPath( _
				m_fso.GetParentFolderName(assemblyPath), m_fso.GetBaseName(assemblyPath) & ".pdb")
	    
		dim proc: set proc = new SyncProcess
		proc.Exec m_fso.BuildPath(m_dotNetObj.FrameworkDir, compilerExeName), _
				"""" & "/out:" & assemblyPath & """ /debug+ " & _
				addlCompilerCmdLineArgs & " " & _
				"""" & recursePrefix & compileFileSpec & """", _
				true, false, 0 'true = failOnErr, false = echoDuring
	end if
    'Run

    set proc = new SyncProcess
    proc.Exec assemblyPath, _
            targetCmdLine, _
            true, not m_outputExit.IsWScriptContext(), 0 'true = failOnErr, echoDuring if cscript context

    ret = proc.OutCapture

    Main = ret
end function

private sub SetWorkingDirIfNec()
    dim file
    for each file in m_fso.GetFolder(m_fso.GetParentFolderName(wscript.ScriptFullName) ).Files 
        if LCase(m_fso.GetFileName(file) ) = NshMainScriptBaseName & ".vbs" then
            exit sub
        end if
    next
    
    'nsh.vbs not found in script dir, so change working-dir to be script-dir
    if m_outputExit.IsScriptVer56OrHigher then
        m_wshell.CurrentDirectory = m_fso.GetParentFolderName(wscript.ScriptFullName)
    end if        
end sub

private function GetOneScreenfull(byval msg)
    const TopThreshold = 10
    const BottomThreshold = 35 
    
    dim ret
    dim start: start = 1
    dim cnt: cnt = 0
    do while start <= len(msg)
        dim ix: ix = InStr(start, msg, vbcrlf)
        if ix < 1 then
            exit do
        end if
        cnt = cnt + 1
        start = ix + len(vbcrlf)            
    loop
    
    dim tot: tot = cnt
    
    if tot > TopThreshold then
        ret = ""
        start = 1
        cnt = 0
        do while start <= len(msg)
            ix = InStr(start, msg, vbcrlf)
            if ix < 1 then
                exit do
            end if
            cnt = cnt + 1
            if cnt = TopThreshold then
                ret = Mid(msg, 1, ix + Len(vbcrlf) - 1) & _
                        ". . ." & vbcrlf
            elseif cnt >= tot - BottomThreshold then
                ret = ret & Mid(msg, ix + Len(vbcrlf) )
                exit do
            end if              
            start = ix + len(vbcrlf)            
        loop
    else
        ret = msg       
    end if
    
    GetOneScreenfull = ret
end function

private function GetQuotedArgs()
    dim ret: ret = ""
    dim args: set args = wscript.Arguments
    dim arg
    for each arg in args
        ret = ret & GetQuotedArg(arg) & " "
    next
    
    GetQuotedArgs = ret
end function

private function GetQuotedArg(byval arg)
    dim ret: ret = arg 'default
    if Instr(arg, " ") >= 1 then
        ret = """" & Replace(arg, """", "\""") & """" 'Quote and escape any embedded quotes
    end if
    GetQuotedArg = ret
end function

private function StripWshHeader(byval capture) 
    dim ret
    
    dim ix: ix = InStr(capture, "Copyright")
    if ix <= 0 then
        ret = capture
    else
        ix = InStr(ix, capture, vbcrlf)
        if ix <= 0 then
            ret = capture
        else
            ret = Mid(capture, ix + 1)
        end if          
    end if      
        
    StripWshHeader = ret
end function

private function IsNshMain()
    IsNshMain = CBool(LCase(m_fso.GetBaseName(wscript.ScriptFullName) ) = NshMainScriptBaseName)
end function

private function DeriveSourceFileFromScriptName() 
    dim ret: ret = ""
    dim baseName: baseName = LCase(m_fso.GetBaseName(wscript.ScriptFullName) )
    dim fld: set fld = m_fso.GetFolder(m_fso.GetParentFolderName(wscript.ScriptFullName) )
    dim file
    for each file in fld.Files
        if LCase(m_fso.GetBaseName(file) ) = baseName then
            if IsDotNetExtFile(file) then
                if ret <> "" then
                    err.Raise GeneralError, "DeriveSourceFileFromScriptName", "More than one .net sourcefile with basename: " & baseName
                end if
                ret = file                  
            end if              
        end if
    next 

    if ret = "" then
        err.Raise GeneralError, "DeriveSourceFileFromScriptName", "No .net sourcefile found with basename: " & baseName
    end if
    
    DeriveSourceFileFromScriptName = ret
end function

private function GetAssemblyPath(byref compileFileSpec, byref mainSourceFile, byref addlCompilerCmdLineArgs, byref useCachedBin)
    dim ret: ret = ""
    useCachedBin = false 'default
    dim tempDirToUse: tempDirToUse = ""
    dim ix: ix = instr(compileFileSpec, "*")
    if ix < 1 then '? No wild card
		tempDirToUse = m_fso.BuildPath(TempDir(), _
				Replace(Replace(Replace(Replace(m_fso.GetAbsolutePathName(compileFileSpec), "\", "-"), "/", "-"), ":", "-"), ".", "-") )
        CreateDirIfNeeded tempDirToUse
        mainSourceFile = GetFilesFromSccIfSpecified(compileFileSpec, tempDirToUse) 'Note Scc currently supported only for non-wildcard
        if mainSourceFile = "" then '? No scc info available
            if not m_fso.FileExists(compileFileSpec) then
                if Len(m_fso.GetFileName(compileFileSpec) ) = Len(compileFileSpec) then '? Is not abs-pathed already
                    dim tryPath: tryPath = m_fso.BuildPath(m_fso.GetParentFolderName(wscript.ScriptFullName), compileFileSpec)
                    if m_fso.FileExists(tryPath) then
                        compileFileSpec = tryPath
                    end if
                end if                
                if not m_fso.FileExists(compileFileSpec) then
                    err.Raise GeneralError, "GetAssemblyPath", "Source file not found: " & compileFileSpec
                end if                
            end if
            mainSourceFile = compileFileSpec
        end if            
        ret = m_fso.BuildPath(tempDirToUse, _
                m_fso.GetBaseName(mainSourceFile) & ".exe")
		'Determine if should use cached copy
		if m_fso.FileExists(ret) then
			'TODO: Don't copy config unless diff datetime
			if m_fso.GetFile(ret).DateLastModified > m_fso.GetFile(compileFileSpec).DateLastModified then
				useCachedBin = true
			end if
		end if
    else 'Wildcard
        dim ixDir: ixDir = InStrRev(compileFileSpec, "/")
        dim ixDir2: ixDir2 = InStrRev(compileFileSpec, "\")
        ixDir = GetMax(ixDir, ixDir2)
        dim path: path = mid(compileFileSpec, 1, ixDir)
        if path = "" then
            path = "."
        end if
        dim filePart: filePart = mid(compileFileSpec, ixDir + 1)
        if not m_fso.FolderExists(path) then
            err.Raise GeneralError, "GetAssemblyPath", "Directory not found: " & path & "(" & compileFileSpec & ")"
        end if
        dim fld: set fld = m_fso.GetFolder(path)
        dim file
        'Look for first non-assemblyInfo file matching fileSpec
        for each file in fld.Files
            if not LCase(m_fso.GetBaseName(file) ) = "assemblyinfo" then
                if filePart = "*" or filePart = "*.*" then
                    tempDirToUse = m_fso.BuildPath(TempDir(), m_fso.GetBaseName(file.Name) )
                    CreateDirIfNeeded tempDirToUse
                    ret = m_fso.BuildPath(tempDirToUse, m_fso.GetBaseName(file.Name) & ".exe")
                    mainSourceFile = file
                    exit for
                elseif InStr(filePart, "*.") = 1 then
                    if LCase(m_fso.GetExtensionName(file.Name) ) = LCase(mid(filePart, 3) ) then
                        tempDirToUse = m_fso.BuildPath(TempDir(), m_fso.GetBaseName(file.Name) )
                        CreateDirIfNeeded tempDirToUse
                        ret = m_fso.BuildPath(tempDirToUse, m_fso.GetBaseName(file.Name) & ".exe")
                        mainSourceFile = file
                        exit for
                    end if                        
                else
                    err.Raise GeneralError, "GetAssemblyPath", "Unsupported wildcard syntax: " & filePart
                end if
            end if
        next
    end if
    
    if ret = "" then
        err.Raise GeneralError, "GetAssemblyPath", "No targetfilename could be derived from: " & filePart
    end if

    'Parse main sourcefile for any extra csc cmd-line args    
    dim commentChr: commentChr = "/" 'default
    if LCase(m_fso.GetExtensionName(mainSourceFile) ) = "vb" then
        commentChr = "'"
    end if        
    addlCompilerCmdLineArgs = "" 'default

    'Ensure valid extension on main sourcefile
    if not IsDotNetExtFile(mainSourceFile) then
        err.Raise GeneralError, "GetAssemblyPath", "Invalid sourcefile extension for file: " & mainSourceFile
    end if

    'Copy configfile if found to to exec targetdir 
    dim configFileSrcName: configFileSrcName = m_fso.BuildPath(m_fso.GetParentFolderName(mainSourceFile), m_fso.GetBaseName(mainSourceFile) & ".config")
    if m_fso.FileExists(configFileSrcName) then '? Config file found
		dim targetConfig: targetConfig = ret & ".config"
		dim isDiff: isDiff = true 'default
		if m_fso.FileExists(targetConfig) then
			if m_fso.GetFile(configFileSrcName).DateLastModified = m_fso.GetFile(targetConfig).DateLastModified then
				isDiff = false
			end if
		end if
		if isDiff then
			CopyOverRO configFileSrcName, targetConfig
		end if
    end if
    
    'Determine if any compiler refs or other supported cmd-line args in sourcefile comment header
    dim ts: set ts = m_fso.OpenTextFile(mainSourceFile)
    do while not ts.AtEndOfStream
        dim line: line = ts.ReadLine()
        if InStr(line, commentChr) <> 1 then '? First non-comment line
            exit do
        end if
        ix = InStr(LCase(line), "/reference:")
        if ix >= 1 then
            dim refFile: refFile = Mid(line, ix + Len("/reference:") )
            dim ixSep: ixSep = InStr(refFile, ",")
            if ixSep >= 1 then
                refFile = mid(refFile, 1, ixSep - 1)
            end if                
            dim refFileToUse: refFileToUse = refFile 'default
            if Len(refFile) <> Len(m_fso.GetAbsolutePathName(refFile) ) then '? Is filename only
                refFileToUse = m_fso.BuildPath(m_fso.GetParentFolderName(m_fso.GetAbsolutePathName(mainSourceFile) ), refFile)
                if not m_fso.FileExists(refFileToUse) then '? Doesn't exist in mainSource dir
                    refFileToUse = m_fso.BuildPath(m_fso.GetParentFolderName(wscript.ScriptFullName), refFile)
                            'Try nsh homedir as fallback
                end if                    
            end if
            dim proc: set proc = new SyncProcess
            CopyAll m_fso.GetParentFolderName(refFileToUse), "dll", tempDirToUse
            CopyAll m_fso.GetParentFolderName(refFileToUse), "pdb", tempDirToUse
            addlCompilerCmdLineArgs = addlCompilerCmdLineArgs & " """ & MapAllRefsIfNeeded(line, refFileToUse) & """"
        end if
    loop
    ts.Close
    
    GetAssemblyPath = ret
end function

sub CopyAll(byval srcDir, byval extFilter, byval destDir)
    const ReadOnlyAttrib = 1
    'Copy all specified files to destination, clearing attribs if nec, copying only if file timestamps differ
    dim file
    if (not m_fso.FolderExists(srcDir) ) then
        err.Raise GeneralError, "CopyAll", "Source dir does not exist: " & srcDir
    end if
    for each file in m_fso.GetFolder(srcDir).Files
        if LCase(m_fso.GetExtensionName(file) ) = LCase(extFilter) then
            dim doCopy: doCopy = true 'default
            dim destFile: destFile = m_fso.BuildPath(destDir, m_fso.GetFileName(file) )
            if m_fso.FileExists(destFile) then
                dim fileObj: set fileObj = m_fso.GetFile(destFile)
                dim fileObjSrc: set fileObjSrc = m_fso.GetFile(file)
                if fileObj.DateLastModified = fileObjSrc.DateLastModified then '? Identical last-mod dates
                    doCopy = false
                end if
                if doCopy then
                    if fileObj.Attributes & ReadOnlyAttrib then
                        fileObj.Attributes = fileObj.Attributes - ReadOnlyAttrib
                    end if                        
                end if
            end if
            if doCopy then
                TryRun "xcopy.exe", _
                        "/I /Y /R """ & file & """ """ & m_fso.GetParentFolderName(destFile) & """", _
                        true
            end if                
        end if
    next
end sub

private function GetFilesFromSccIfSpecified(byval mainSourceFile, byval targetDir)
    const ConfigSccSuffix = ".configscc"
    dim ret: ret = "" 'default
    
    'Determine if .configss file exists, and if so specifies a non-blank repos--if so, use this to get latest
    dim configSccFile: configSccFile = m_fso.BuildPath(m_fso.GetParentFolderName(mainSourceFile), m_fso.GetBaseName(mainSourceFile) & ConfigSccSuffix) 
    if m_fso.FileExists(configSccFile) then
        dim xml: set xml = new MsXmlWrapper
        xml.Load configSccFile
        dim sccRepos: sccRepos = xml.SelectSingleExistingNode("/configuration/appSettings/add[@key=""SccRepository""]").GetAttribute("value")
        if sccRepos <> "" then '? non-blank repos specified
            ret = mainSourceFile
            dim sccUser: sccUser = xml.SelectSingleExistingNode("/configuration/appSettings/add[@key=""SccUser""]").GetAttribute("value")
            dim sccPassword: sccPassword = xml.SelectSingleExistingNode("/configuration/appSettings/add[@key=""SccPassword""]").GetAttribute("value")
            
            dim scc: set scc = new SCCAccess
            scc.OpenRepository sccRepos, sccUser, sccPassword
            scc.GetLatestFile mainSourceFile
            dim configFileName: configFileName = m_fso.BuildPath(m_fso.GetParentFolderName(mainSourceFile), m_fso.GetBaseName(mainSourceFile) & ".config")
            if scc.Files(m_fso.GetParentFolderName(mainSourceFile) ).Exists(LCase(m_fso.GetFileName(configFileName) ) ) then '? Config file found
                scc.GetLatestFile configFileName
            end if                    
        end if
        
        'Copy .configscc file to target exec dir
        CopyOverRO configSccFile, _
                m_fso.BuildPath(targetDir, m_fso.GetBaseName(mainSourceFile) & ".exe" & ConfigSccSuffix)
    end if

    GetFilesFromSccIfSpecified = ret
end function

private function IsDotNetExtFile(byval file)
    select case LCase(m_fso.GetExtensionName(file) )
        case "cs", "vb", "js"
            IsDotNetExtFile = true
        case else
            IsDotNetExtFile = false
    end select
end function

private function MapAllRefsIfNeeded(byval line, byval refFileToUseFullPath)
    dim ret: ret = "/reference:"
    dim ix: ix = InStr(LCase(line), "/reference:") + Len("/reference:")
    do while ix <= Len(line)
        dim aRef: aRef = Trim(mid(line, ix) )
        dim ixEnd: ixEnd = InStr(aRef, ",")
        if ixEnd >= 1 then
            aRef = trim(mid(aRef, 1, ixEnd - 1) )
            ix = ix + ixEnd
        end if
        if Len(aRef) = Len(m_fso.GetFileName(aRef) ) and not IsSystemRef(aRef) then '? filename only
            aRef = m_fso.BuildPath(m_fso.GetParentFolderName(refFileToUseFullPath), aRef)
        end if
        ret = ret & aRef
        if ixEnd >= 1 then            
            ret = ret & ","
        else            
            exit do
        end if            
    loop
    
    MapAllRefsIfNeeded = ret
end function

private function IsSystemRef(byval aRef)
    dim arg: arg = LCase(aRef)
    IsSystemRef = CBool(InStr(arg, "system.") = 1 or _
            InStr(arg, "microsoft.") = 1 or _
            InStr(arg, "ms") = 1 or _
            InStr(arg, "adodb.") = 1)
end function

private function GetMax(byval arg1, byval arg2)
    dim ret
    if arg1 >= arg2 then
        ret = arg1
    else
        ret = arg2
    end if
    
    GetMax = ret                
end function

'''<summary>
'''Run specified executable synchronously (wait indefinitely for it to exit)
'''</summary>
'''<returns>string capture of stdout, stderr</returns>
'''<throws>If could not run cmd</throws>
'''<throws>if cmd returns non-0 and errOnFail</throws>
function TryRun(byval cmd, byval cmdLine, byval errOnFail)
    dim proc: set proc = new SyncProcess
    proc.Exec cmd, cmdline, errOnFail, false, 0 'false = echoDuring, 0 = timeoutMs
    TryRun = proc.OutCapture
end function

'''<summary>
''SyncProcess class--supports running an app synchronously (waiting for exit)
'''</summary>
class SyncProcess
    private m_execObj
    private m_outCapture
    private m_exitCode
    
    '''<summary>
    '''Execute specified command with optional cmd-line args, waiting for return
    '''</summary>
    '''<param name="cmd">executable or batchfile name</param>
    '''<param name="cmdLine">cmd-line params if any</param>
    '''<param name="failOnError">throw exception if non-0 exit code</param>
    '''<param name="echoDuring">echo stdout as app runs. If this true, timeOutMs must be 0.</param>
    '''<param name="timeOutms">Max time to allow app to run (kill after this time). If this non-0, echoDuring must be false.</param>
    sub Exec(byval cmd, byval cmdLine, byval failOnError, byval echoDuring, byval timeOutms)
        if echoDuring and timeOutms <> 0 then
            Err.Raise GeneralError, "Exec", "Can't specify both echoDuring and non-0 timeOutms"
        end if
        if timeOutms <> 0 then
            if m_outputExit.IsWindowsInstallerContext then
                Err.Raise GeneralError, "Exec", "Can't specify timeout when in Windows Installer context"
            else
                m_OutputExit.WriteLine "**WARNING: Timeout not currently implemented for Windows Installer context"
            end if
        end if
        m_outCapture = ""
        dim begTime: begTime = Now()
        
        if m_OutputExit.IsWScriptContext() and timeOutms = 0 and not echoDuring then
            'avoid a visible cmd-prompt window with alternative implementation
            ExecMinimized cmd, cmdLine, failOnError
            exit sub
        elseif not m_outputExit.IsScriptVer56OrHigher() then
            if echoDuring then
                m_outputExit.WriteLine "**WARNING: echoDuring not available with WSH 5.1"
            end if
            ExecMinimized cmd, cmdLine, failOnError
            exit sub
        elseif m_OutputExit.IsWScriptContext() and echoDuring then
            ExecVisibleWindowEchoDuring cmd, cmdLine, failOnError           
            exit sub
        end if
        
        dim line                          
        err.Clear
        on error resume next
        set m_execObj = m_wshell.Exec("""" & cmd & """" & " " & cmdLine)
        dim errNumber: errNumber = err.number
        dim errDescription: errDescription = err.Description
        on error goto 0
        
        if errNumber <> 0 then '? Could not invoke program at all
            err.raise GeneralError, "Exec", "Could not execute: " & cmd & ": " & _
                    errDescription
        end if

        do while m_execObj.Status = 0 'Until app exited
            if timeOutMs <> 0 then
                dim diffMs: diffMs = datediff("s", begTime, now() ) * 1000
                if diffMs >= timeOutMs then
                    m_execObj.Terminate
                    Err.Raise GeneralError, "Exec", cmd & " exceeded timeout--terminated after " & diffMs & "ms"
                end if
                wscript.sleep 200
            else 'Not being timed out
                'Note: Blocks waiting for stdout here (so no sleep needed)
                If Not m_execObj.StdOut.AtEndOfStream Then 
                    line = m_execObj.StdOut.ReadLine
                    if m_outCapture <> "" then
                        m_outCapture = m_outCapture & vbcrlf
                    end if
                    m_outCapture = m_outCapture & line
                    if echoDuring then
                        m_OutputExit.WriteLine line
                    end if
                end if
            end if
        loop
        
        'First get rest of stdout
        do while Not m_execObj.StdOut.AtEndOfStream 
            line = m_execObj.StdOut.ReadLine
            if m_outCapture <> "" then
                m_outCapture = m_outCapture & vbcrlf
            end if
            m_outCapture = m_outCapture & line
            if echoDuring then
                m_OutputExit.WriteLine line
            end if
        loop

        'Lastly get stderr if any
        do while Not m_execObj.StdErr.AtEndOfStream 
            line = m_execObj.StdErr.ReadLine
            if m_outCapture <> "" then
                m_outCapture = m_outCapture & vbcrlf
            end if
            m_outCapture = m_outCapture & line
            if echoDuring then
                m_OutputExit.WriteLine line
            end if
        loop
        
        m_exitCode = m_execObj.ExitCode
        if m_exitCode <> 0 then
            dim captureToUse
            if echoDuring then
                captureToUse = ""
            else
                captureToUse = vbcrlf & m_outCapture
            end if
            if m_exitCode = ReservedNshNoMsgExitCode then
                m_NoMsgOptionSet = true
                exit sub 'No error 
            elseif failOnError then
                Err.Raise GeneralError, "Exec", "Non-0 return (" & m_exitCode & ") from: " & cmd & " " & cmdLine & captureToUse
            else
                m_OutputExit.WriteLine "**WARN: Non-0 return (" & m_exitCode & "): " & cmd & " " & cmdLine
            end if
        end if
    end sub

    property get ExitCode
        ExitCode = m_exitCode
    end property
    
    private sub ExecMinimized(byval cmd, byval cmdLine, byval failOnError)
        if m_toolUtilsObj.IsCmdExeAvail then
            ExecMinimizedCmdExe cmd, cmdLine, failOnError
        else
            ExecMinimizedExt cmd, cmdLine, failOnError
        end if
    end sub
    
    private sub ExecMinimizedExt(byval cmd, byval cmdLine, byval failOnError)
        dim tempFileName: tempFileName = GetTempFileName()

        err.clear
        on error resume next
        dim locExitCode: locExitCode = m_wshell.run( _
                """" & m_fso.BuildPath(m_OutputExit.ToolsDir, "SysUtils.exe") & """" & _
                " " & """" & "-runprocess:exe:" & Replace(cmd, """", "\""") & " " & _
                "cmdline:" & Replace(cmdLine, """", "\""") & " " & _
                "stdouterrcap:" & tempFileName & """", _
                7, true) '7 = minimized-window, true = run synchronously

        dim errNumber: errNumber = err.number
        dim errDescription: errDescription = err.Description
        on error goto 0
        
        dim stdErrOut: stdErrOut = ReadFileToString(tempFileName)
        m_fso.DeleteFile tempFileName, true 'true = force R/O delete
        if stdErrOut <> "" then
            stdErrOut = vbcrlf & stdErrOut
        end if        
        if errNumber <> 0 or locExitCode <> 0 then '? Could not invoke SysUtils.exe
            err.raise GeneralError, "ExecMinimizedExt", "Could not execute: SysUtils.exe--" & cmd & " " & cmdLine & " (" & _
                    errDescription & ")" & vbcrlf & stdErrOut
        end if
        m_exitCode = CInt(m_toolUtilsObj.FindSuffixToEOL("exitcode:", stdErrOut) )
        stdErrOut = m_toolUtilsObj.FindSuffixToEOS("stdouterr:", stdErrOut)
        m_outCapture = stdErrOut
        if m_exitCode <> 0 then '? Program invoked, but returned error
            if m_exitCode = ReservedNshNoMsgExitCode then
                m_NoMsgOptionSet = true
                exit sub 'No error 
            elseif failOnError then
                err.raise GeneralError, "ExecMinimized", "Non-0 error return: " & m_exitCode & ": " & cmd & " " & cmdLine & stdErrOut
            else            
                m_outputExit.WriteLine "**WARN: Non-0 error return: " & m_exitCode & ": " & cmd & " " & cmdLine
            end if        
        end if      
    end sub
    
    private sub ExecVisibleWindowEchoDuring(byval cmd, byval cmdLine, byval failOnError)
        dim tempFile: tempFile = GetTempFileName()
        dim tempScript: tempScript = m_fso.BuildPath(m_fso.GetParentFolderName(tempFile), _
                m_fso.GetBaseName(tempFile) & ".vbs")
        dim ts: set ts = m_fso.OpenTextFile(tempscript, 2, true) '2 = ForWriting
        ts.WriteLine _
            "option explicit" & vbcrlf & _
            "const Cmd = """ & cmd & """" & vbcrlf & _
            "const CmdLine = """ & Replace(cmdLine, """", """""") & """" & vbcrlf & _
            "const TempFile = """  & tempFile & """" & vbcrlf & _
            "const FailOnError = " & failOnError & vbcrlf & _
            "const EchoDuring = true" & vbcrlf & _
            "const GeneralError = &h80040200" & vbcrlf & _
            "dim m_fso: set m_fso = CreateObject(""scripting.filesystemobject"")" & vbcrlf & _
            "dim m_wshell: set m_wshell = CreateObject(""wscript.shell"")" & vbcrlf & _
            "dim m_ts: set m_ts = nothing" & vbcrlf & _
            "err.Clear" & vbcrlf & _
            "on error resume next" & vbcrlf & _
            "dim msg" & vbcrlf & _
            "" & vbcrlf & _
            "Main" & vbcrlf & _
            "" & vbcrlf & _
            "if err.number <> 0 then '? ERR" & vbcrlf & _
            "   msg = ""FAILURE."" & vbcrlf & vbcrlf & err.Description" & vbcrlf & _
            "   if m_ts <> nothing then" & vbcrlf & _
            "       m_ts.WriteLine msg" & vbcrlf & _
            "       m_ts.Close" & vbcrlf & _
            "   end if" & vbcrlf & _
            "   on error goto 0" & vbcrlf & _
            "   wscript.Quit 1" & vbcrlf & _
            "else" & vbcrlf & _
            "   on error goto 0" & vbcrlf & _
            "   wscript.Quit 0" & vbcrlf & _
            "end if" & vbcrlf & _
            "" & vbcrlf & _
            "sub Main()" & vbcrlf & _
            "   set m_ts = m_fso.OpenTextFile(TempFile, 2, true) '2 = ForWriting" & vbcrlf & _
            "" & vbcrlf & _
            "   m_ts.Write ExecCapStdOut()" & vbcrlf & _
            "   m_ts.Close" & vbcrlf & _
            "   set m_ts = nothing" & vbcrlf & _
            "end sub" & vbcrlf & _
            "" & vbcrlf & _
            "Function GetTempFileName()" & vbcrlf & _
            "   Dim tfolder, tname, tfile" & vbcrlf & _
            "   dim ret" & vbcrlf & _
            "" & vbcrlf & _
            "   Const TemporaryFolder = 2" & vbcrlf & _
            "   err.clear" & vbcrlf & _
            "   on error resume next" & vbcrlf & _
            "   Set tfolder = m_fso.GetSpecialFolder(TemporaryFolder)" & vbcrlf & _
            "   dim errNumber: errNumber = err.Number" & vbcrlf & _
            "   dim errDescription: errDescription = err.Description" & vbcrlf & _
            "   on error goto 0" & vbcrlf & _
            "   if errNumber <> 0 then" & vbcrlf & _
            "           err.raise GeneralError, ""GetTempFileName"", ""error getting temp folder--probably does not exist--"" & errDescription" & vbcrlf & _
            "   end if" & vbcrlf & _
            "   tname = m_fso.GetTempName" & vbcrlf & _
            "   Set tfile = tfolder.CreateTextFile(tname)" & vbcrlf & _
            "   tfile.close" & vbcrlf & _
            "   ret = m_fso.BuildPath(tfolder.path, tname)" & vbcrlf & _
            "   GetTempFileName = ret" & vbcrlf & _
            "End Function" & vbcrlf & _
            "" & vbcrlf & _
            "function ExecCapStdOut()" & vbcrlf & _
            "   dim outCapture: outCapture = """"" & vbcrlf & _
            "   dim line" & vbcrlf & _
            "   err.Clear" & vbcrlf & _
            "   on error resume next" & vbcrlf & _
            "   dim execObj: set execObj = m_wshell.Exec("""""""" & Cmd & """""""" & "" "" & CmdLine)" & vbcrlf & _
            "   dim errNumber: errNumber = err.number" & vbcrlf & _
            "   dim errDescription: errDescription = err.Description" & vbcrlf & _
            "   on error goto 0" & vbcrlf & _
            "   if errNumber <> 0 then '? Could not invoke program at all" & vbcrlf & _
            "       err.raise GeneralError, ""Exec"", ""Could not execute: "" & Cmd & "": "" & _" & vbcrlf & _
            "               errDescription" & vbcrlf & _
            "   end if" & vbcrlf & _
            "" & vbcrlf & _
            "   do while execObj.Status = 0 'Until app exited" & vbcrlf & _
            "       'Note: Blocks waiting for stdout here (so no sleep needed)" & vbcrlf & _
            "       If Not execObj.StdOut.AtEndOfStream Then" & vbcrlf & _
            "           line = execObj.StdOut.ReadLine" & vbcrlf & _
            "           if EchoDuring then" & vbcrlf & _
            "               wscript.echo line" & vbcrlf & _
            "           end if" & vbcrlf & _
            "           if outCapture <> """" then" & vbcrlf & _
            "               outCapture = outCapture & vbcrlf" & vbcrlf & _
            "           end if" & vbcrlf & _
            "           outCapture = outCapture & line" & vbcrlf & _
            "       end if" & vbcrlf & _
            "   loop" & vbcrlf & _
            "" & vbcrlf & _
            "   'First get rest of stdout" & vbcrlf & _
            "   do while Not execObj.StdOut.AtEndOfStream" & vbcrlf & _
            "       line = execObj.StdOut.ReadLine" & vbcrlf & _
            "       if EchoDuring then" & vbcrlf & _
            "           wscript.echo line" & vbcrlf & _
            "       end if" & vbcrlf & _
            "       if outCapture <> """" then" & vbcrlf & _
            "           outCapture = outCapture & vbcrlf" & vbcrlf & _
            "       end if" & vbcrlf & _
            "       outCapture = outCapture & line" & vbcrlf & _
            "   loop" & vbcrlf & _
            "" & vbcrlf & _
            "   'Lastly get stderr if any" & vbcrlf & _
            "   do while Not execObj.StdErr.AtEndOfStream" & vbcrlf & _
            "       line = execObj.StdErr.ReadLine" & vbcrlf & _
            "       if EchoDuring then" & vbcrlf & _
            "           wscript.echo line" & vbcrlf & _
            "       end if" & vbcrlf & _
            "       if outCapture <> """" then" & vbcrlf & _
            "           outCapture = outCapture & vbcrlf" & vbcrlf & _
            "       end if" & vbcrlf & _
            "       outCapture = outCapture & line" & vbcrlf & _
            "   loop" & vbcrlf & _
            "" & vbcrlf & _
            "   dim exitCode: exitCode = execObj.ExitCode" & vbcrlf & _
            "   if exitCode <> 0 then" & vbcrlf & _
            "       if FailOnError then" & vbcrlf & _
            "           Err.Raise GeneralError, ""Exec"", ""Non-0 return ("" & exitCode & "") from: "" & Cmd & "" "" & CmdLine & vbcrlf & outCapture" & vbcrlf & _
            "       else" & vbcrlf & _
            "           dim msg: msg = ""**WARN: Non-0 return ("" & exitCode & ""): "" & Cmd & "" "" & CmdLine & vbcrlf" & vbcrlf & _
            "           wscript.echo msg" & vbcrlf & _
            "           outCapture = msg & outCapture" & vbcrlf & _
            "       end if" & vbcrlf & _
            "   end if" & vbcrlf & _
            "" & vbcrlf & _
            "   ExecCapStdOut = outCapture" & vbcrlf & _
            "end function" & vbcrlf
        ts.Close
        
        err.clear
        on error resume next
        m_exitCode = m_wshell.run( _
                "cscript.exe """ & tempScript & """", _
                1, true) '1 = normal-window, true = run synchronously

        dim errNumber: errNumber = err.number
        dim errDescription: errDescription = err.Description
        on error goto 0
        m_fso.DeleteFile tempScript, true 'true = force R/O delete
        
        dim stdErrOut: stdErrOut = ReadFileToString(tempFile)
        m_fso.DeleteFile tempFile, true 'true = force R/O delete
        if stdErrOut <> "" then
            stdErrOut = vbcrlf & stdErrOut
        end if        
        if errNumber <> 0 then '? Could not invoke cscript.exe
            err.raise GeneralError, "ExecVisibleWindowEchoDuring", "Could not execute: cscript.exe--" & cmd & " " & cmdLine & " (" & _
                    errDescription & ")" & vbcrlf & stdErrOut
        end if
        m_outCapture = stdErrOut
        if m_exitCode <> 0 then '? Program invoked, but returned error
            if m_exitCode = ReservedNshNoMsgExitCode then
                m_NoMsgOptionSet = true
                exit sub 'No error 
            elseif failOnError then
                err.raise GeneralError, "ExecMinimized", "Non-0 error return: " & m_exitCode & ": " & cmd & " " & cmdLine & stdErrOut
            else            
                m_outputExit.WriteLine "**WARN: Non-0 error return: " & m_exitCode & ": " & cmd & " " & cmdLine
            end if        
        end if      
        
    end sub

    private sub ExecMinimizedCmdExe(byval cmd, byval cmdLine, byval failOnError)
        dim tempFileName: tempFileName = GetTempFileName()

        err.clear
        on error resume next
        m_exitCode = m_wshell.run("cmd.exe /c """"" & cmd & """ " & cmdLine & " >""" & tempFileName & """ 2>&1""", 7, true) '7 = minimized-window, true = run synchronously
        dim errNumber: errNumber = err.number
        dim errDescription: errDescription = err.Description
        on error goto 0
        
        dim stdErrOut: stdErrOut = ReadFileToString(tempFileName)
        m_fso.DeleteFile tempFileName, true 'true = force R/O delete
        if stdErrOut <> "" then
            stdErrOut = vbcrlf & stdErrOut
        end if        
        if errNumber <> 0 then '? Could not invoke program at all
            err.raise errNumber, "ExecMinimizedCmdExe", "Could not execute: " & cmd & " " & cmdLine & " (" & _
                    errDescription & ")" & stdErrOut
        end if
        m_outCapture = stdErrOut
        if m_exitCode <> 0 then '? Program invoked, but returned error
            ThrowIfCmdDoesntExist cmd 'Since cmd.exe used above, an exception won't usually occur above...
                                      'try to determine if specified executable doesn't exist here
            if m_exitCode = ReservedNshNoMsgExitCode then
                m_NoMsgOptionSet = true
                exit sub 'No error 
            elseif failOnError then
                err.raise GeneralError, "ExecMinimizedCmdExe", "Non-0 error return: " & ExitCode & ": " & cmd & " " & cmdLine & stdErrOut
            else            
                m_outputExit.WriteLine "**WARN: Non-0 error return: " & ExitCode & ": " & cmd & " " & cmdLine
            end if        
        end if      
    end sub

    '''<summary>
    '''Get stdout & stderr capture from prior Exec() call
    '''</summary>
    property get OutCapture
        OutCapture = m_outCapture
    end property
    
    private sub ThrowIfCmdDoesntExist(byval cmd)
        dim fileName: fileName = m_fso.GetFileName(cmd)
        if LCase(fileName) = LCase(cmd) then '? Not an explicit path specified
            exit sub
        end if
        
        if not m_fso.FileExists(cmd) then '? specified executable doesn't exist
            err.raise GeneralError, "ExecMinimized", "Could not find: " & cmd
        end if
    end sub
end class

'''<summary>
''ToolUtils class--wraps access to tools utilities
'''</summary>
class ToolUtils
    private m_scriptRegEditMethod
    private m_cmdExeMethod
    
    sub CopyFileOverwriteRO(byval src, byval dest, byval clearDestRO)
        m_outputExit.WriteLine "Copying " & src & " -> " & dest
        if m_fso.FileExists(dest) then
            ClearROAttrib dest
        end if
        
        m_fso.CopyFile src, dest
        if clearDestRO then
            ClearROAttrib dest
        end if            
    end sub
    
    sub ClearROAttrib(byval file)
        const ReadOnlyAttrib = 1
        dim fileObj: set fileObj = m_fso.GetFile(file)
        if fileObj.Attributes and ReadOnlyAttrib then
            fileObj.Attributes = fileObj.Attributes - ReadOnlyAttrib
        end if
    end sub
    
    sub Touch(byval fileName)
        m_outputExit.WriteLine "Touching file " & fileName
        TryRun m_fso.BuildPath(m_OutputExit.ToolsDir, "SysUtils.exe"), _
                """-touch:" & filename & """", true 'true = errOnFail
    end sub

    '''<summary>
    '''Read registry value
    '''</summary>
    '''<throws>Exception if key / value does not exist</throws>
    Function GetRegistryValue(byval regValuePath)
        m_scriptRegEditMethod = "script"
        
        dim ret
        if m_scriptRegEditMethod = "script" then
            err.clear
            on error resume next
            ret = m_wshell.RegRead(regValuePath)
            if err.number <> 0 then '? ERR
                dim errMsg: errMsg = err.Description
                on error goto 0
                err.Raise GeneralError, "GetRegistryValue", "Could not read registry value: " & regValuePath & errMsg
            end if
            on error goto 0
        else
            err.Raise GeneralError, "GetRegistryValue", "unexpected: " & m_scriptRegEditMethod
        end if            
        
        GetRegistryValue = ret
    end function

    function FindSuffixToEOL(byval prefix, byval linesBlock)
        dim i: i = InStr(1, linesBlock, prefix)
        if i < 1 then
            err.raise GeneralError, "FindSuffixToEOL", prefix & " not found"
        end if 
        dim ret: ret = mid(linesBlock, i + len(prefix) )
        dim iNewLine: iNewLine = InStr(1, ret, vbcrlf)
        if iNewLine >= 1 then
            ret = mid(ret, 1, iNewLine - 1)
        end if
        
        FindSuffixToEOL = ret
    end function
    
    function FindSuffixToEOS(byval prefix, byval linesBlock)
        dim i: i = InStr(1, linesBlock, prefix)
        if i < 1 then
            err.raise GeneralError, "FindSuffixToEOL", prefix & " not found"
        end if 
        dim ret: ret = mid(linesBlock, i + len(prefix) )
        
        FindSuffixToEOS = ret
    end function
    
    property get IsCmdExeAvail 
        const KnownGoodCmdExeCmd = "cmd.exe /c cd"
        if m_cmdExeMethod = "" then
            err.Clear
            on error resume next
            dim locExitCode: locExitCode = m_wshell.run(KnownGoodCmdExeCmd, 7, true) '7 = minimized-window, true = run synchronously
            if err.number <> 0 or locExitCode <> 0 then '? ERR
                m_cmdExeMethod = "ext"
            else 'OK
                m_cmdExeMethod = "script"
            end if  
            on error goto 0              
        end if
        
        IsCmdExeAvail = CBool(m_cmdExeMethod = "script")
    end property
    
    private sub class_initialize()
        m_scriptRegEditMethod = ""
        m_cmdExeMethod = ""
    end sub
end class

private sub CopyOverRO(byval fromFile, byval toFile)
    if m_fso.FileExists(toFile) then
        m_fso.DeleteFile toFile, true 'true = force
    end if
    
    m_fso.CopyFile fromFile, toFile, true 'true = overWriteFiles        
end sub

private sub DeleteFileIfExists(byval file) 
    if m_fso.FileExists(file) then
        err.Clear
        on error resume next
        m_fso.DeleteFile file, true
        if err.number <> 0 then
            dim errDescription: errDescription = err.Description
            on error goto 0
            err.Raise GeneralError, "DeleteFileIfExists", "Could not delete file: " & file & ": " & errDescription
        end if
        on error goto 0
    end if
end sub

private sub CreateDirIfNeeded(byval dirName)
    if not m_fso.FolderExists(dirName) then
        err.Clear
        on error resume next
        m_fso.CreateFolder dirName
        if err.number <> 0 then
            dim errDescription: errDescription = err.Description
            on error goto 0
            err.Raise GeneralError, "CreateDirIfNeeded", "Could not create dir: " & dirName & ": " & errDescription
        end if
        on error goto 0
    end if
end sub

'''<summary>
''DotNetUtils class--wraps access to .NET framework utilities 
'''</summary>
class DotNetUtils
    private m_netFrameworkDir
    
    sub RegisterToGac(byval assemblyFile, byval failIfNoAssemblyFile)
        m_outputExit.WriteLine "Registering to GAC " & assemblyFile
        
        if not m_fso.FileExists(assemblyFile) then
            if failIfNoAssemblyFile then
                err.Raise GeneralError, "RegisterToGac", "File not found: " & assemblyFile
            else
                m_outputExit.WriteLine "**WARNING: File not found: " & assemblyFile
                exit sub
            end if                
        end if
        
        TryRun m_fso.BuildPath(FrameworkDir, "gacutil.exe"), _
                "-if " & """" & assemblyFile & """", _
                true 'true = failOnError
    end sub
    
    sub UnregisterFromGac(byval assemblyName, byval strongNameInfo)
        dim assyNameToUse
        if strongNameInfo = "" then
            assyNameToUse = assemblyName
            m_outputExit.WriteLine "Un-registering from GAC all versions of " & assyNameToUse
        else
            assyNameToUse = assemblyName & "," & strongNameInfo
            m_outputExit.WriteLine "Un-registering from GAC " & assyNameToUse
        end if

        TryRun m_fso.BuildPath(FrameworkDir, "gacutil.exe"), _
                "-u " & assyNameToUse, _
                true 'true = failOnError
    end sub

    '''<summary>
    '''Determine if one or more versions of AssemblyName exist in GAC
    '''</summary>
    function GacAssemblyExists(byval assemblyName)
        dim stdOut: stdOut = TryRun(m_fso.BuildPath(FrameworkDir, "gacutil.exe"), _
                "-l " & assemblyName, _
                true) 'true = failOnError
        GacAssemblyExists = (InStr(1, LCase(stdOut), LCase(assemblyName) & ",") >= 1)
    end function
    
    sub RegisterToComPlus(byval assemblyFile, byval appName, byval failIfNoAssemblyFile)
        m_outputExit.WriteLine "Registering to COM+ " & appName

        if not m_fso.FileExists(assemblyFile) then
            if failIfNoAssemblyFile then
                err.Raise GeneralError, "RegisterToComPlus", "File not found: " & assemblyFile
            else
                m_outputExit.WriteLine "**WARNING: File not found: " & assemblyFile
                exit sub
            end if                
        end if

        TryRun m_fso.BuildPath(FrameworkDir, "regsvcs.exe"), _
                """" & assemblyFile & """" & " /appname:" & appName, _
                true 'true = failOnError
    end sub
    
    sub UnregisterFromComPlus(byval assemblyFile, byval failIfNoAssemblyFile)
        m_outputExit.WriteLine "Un-registering from COM+ " & assemblyFile

        if not m_fso.FileExists(assemblyFile) then
            if failIfNoAssemblyFile then
                err.Raise GeneralError, "UnregisterFromComPlus", "File not found: " & assemblyFile
            else
                m_outputExit.WriteLine "**WARNING: File not found: " & assemblyFile
                exit sub
            end if                
        end if

        TryRun m_fso.BuildPath(FrameworkDir, "regsvcs.exe"), _
                "/u " & """" & assemblyFile & """", _
                true 'true = failOnError
    end sub
    
    '''<summary>
    '''Run the .NET installer for an assembly w/o passing any installerclass-specific options
    '''</summary>
    sub InstallAssembly(byval assemblyFile, byval failIfNoAssemblyFile)
        m_outputExit.WriteLine "Installing " & assemblyFile

        if not m_fso.FileExists(assemblyFile) then
            if failIfNoAssemblyFile then
                err.Raise GeneralError, "InstallAssembly", "File not found: " & assemblyFile
            else
                m_outputExit.WriteLine "**WARNING: File not found: " & assemblyFile
                exit sub
            end if                
        end if

        TryRun m_fso.BuildPath(FrameworkDir, "installutil.exe"), _
                "/LogFile= /LogToConsole=true " & """" & assemblyFile & """", _
                true 'true = failOnError
    end sub
    
    '''<summary>
    '''Run the .NET installer for a service assembly,  passing in service userid and password
    '''</summary>
    '''<remarks>
    '''Passing in non-blank for username and password will override the default behavior of a 
    ''''service assembly prompting for user and password
    ''' (when .Account is the default "User" type and Username and Password are null).
    '''</remarks>
    sub InstallServiceAssembly(byval assemblyFile, byval userName, byval password, byval failIfNoAssemblyFile)
        dim args: args = "" 'default
        if userName <> "" then
            args = "/username=" & userName & " /password=" & password
        end if
        m_outputExit.WriteLine "Installing " & assemblyFile

        if not m_fso.FileExists(assemblyFile) then
            if failIfNoAssemblyFile then
                err.Raise GeneralError, "InstallServiceAssembly", "File not found: " & assemblyFile
            else
                m_outputExit.WriteLine "**WARNING: File not found: " & assemblyFile
                exit sub
            end if                
        end if

        TryRun m_fso.BuildPath(FrameworkDir, "installutil.exe"), _
                args & " /LogFile= /LogToConsole=true " & """" & assemblyFile & """", _
                true 'true = failOnError
    end sub
    
    '''<summary>
    '''Run the .NET uninstaller for an assembly
    '''</summary>
    sub UninstallAssembly(byval assemblyFile, byval failIfNoAssemblyFile, byval failOnUninstallerError)
        m_outputExit.WriteLine "Un-installing " & assemblyFile

        if not m_fso.FileExists(assemblyFile) then
            if failIfNoAssemblyFile then
                err.Raise GeneralError, "UninstallAssembly", "File not found: " & assemblyFile
            else
                m_outputExit.WriteLine "**WARNING: File not found: " & assemblyFile
                exit sub
            end if                
        end if

        TryRun m_fso.BuildPath(FrameworkDir, "installutil.exe"), _
                "/u /LogFile= /LogToConsole=true " & """" & assemblyFile & """", _
                failOnUninstallerError 'failOnUninstallerError = failOnError
    end sub
    
    property get FrameworkDir
        if m_netFrameworkDir = "" then
            'Get .NET framework path
            dim netInstallDir: netInstallDir = m_toolUtilsObj.GetRegistryValue("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework\InstallRoot")
            'Find last folder that has csc.exe and use that
            const ExeToFind = "csc.exe"
            dim found: found = false
            dim fld
            for each fld in m_fso.GetFolder(netInstallDir).SubFolders
                dim file
                For Each file In fld.Files
                    if LCase(m_fso.GetFileName(file) ) = ExeToFind then
                        found = true
                        m_netFrameworkDir = fld.Path
                    end if
                next
            next
            if not found then
                err.Raise GeneralError, "FrameworkDir", ExeToFind & " not found in any subfolder of " & m_netFrameworkDir
            end if
        end if
                
        FrameworkDir = m_netFrameworkDir
    end property
        
    private sub class_initialize()
        m_netFrameworkDir = ""
    end sub
end class

'''<summary>
''OutputExit class--abstracts what calling context used to perform appropriate output and exit
'''</summary>
class OutputExit

    '''<summary>
    '''Write line appropriately depending on calling context
    '''</summary>
    sub WriteLine(byval str)
        wscript.echo str            
    end sub 
    
    '''<summary>
    '''Quit appropriately depending on calling context
    '''</summary>
    '''<postcond>Appropriate return value(s) delivered to calling context</postcond>
    sub Quit(byval num)
        wscript.Quit num
    end sub


    public function IsWScriptContext()
        dim ret: ret = false 'default
        if LCase(m_fso.GetBaseName(WScript.FullName) ) = "wscript" then
            ret = true
        end if
        
        IsWScriptContext = ret
    end function
    
    public function IsScriptVer56OrHigher()
        IsScriptVer56OrHigher = CBool(ScriptVersion() >= 5.6)
    end function
    
    public function ScriptVersion()
        ScriptVersion = CDbl(wscript.version)
    end function
    
end class

'''<summary>
'''Read contents of file into string
'''</summary>
Function ReadFileToString(byval fn)
    dim ret: ret = ""
    dim ts: set ts = m_fso.OpenTextFile(fn, 1) '1 = reading
    do while not ts.AtEndOfStream
        dim ln: ln = ts.ReadLine()
        if ret <> "" then
            ret = ret & vbcrlf
        end if            
        ret = ret & ln        
    loop
    ts.Close
    
    ReadFileToString = ret
end function

'''<summary>
'''Get an OS-assigned tempfile name
'''</summary>
Function GetTempFileName()
   Dim tfolder, tname, tfile
   dim ret
   
   Const TemporaryFolder = 2
   err.clear
   on error resume next
   Set tfolder = m_fso.GetSpecialFolder(TemporaryFolder)
   dim errNumber: errNumber = err.Number
   dim errDescription: errDescription = err.Description
   on error goto 0
   if errNumber <> 0 then
        err.raise GeneralError, "GetTempFileName", "error getting temp folder--probably does not exist--" & errDescription
   end if
   tname = m_fso.GetTempName    
   Set tfile = tfolder.CreateTextFile(tname)
   tfile.close
   ret = m_fso.BuildPath(tfolder.path, tname)
   GetTempFileName = ret
End Function

'''<summary>
'''Get OS temp location
'''</summary>
Function TempDir()
    dim ret, tfolder

    Const TemporaryFolder = 2
    err.clear
    on error resume next
    Set tfolder = m_fso.GetSpecialFolder(TemporaryFolder)
    dim errNumber: errNumber = err.Number
    dim errDescription: errDescription = err.Description
    on error goto 0
    if errNumber <> 0 then
        err.raise GeneralError, "GetTempFileName", "error getting temp folder--probably does not exist--" & errDescription
    end if

    ret = tfolder.Path
    TempDir = ret
end function

'''<summary>
''Wraps MSXML2
'''</summary>
class MsXmlWrapper
    private m_doc
    
    public sub Load(byval xmlFile)
        err.Clear
        on error resume next
        set m_doc = CreateObject("MSXML2.DomDocument")
        dim errDescription
        if err.number <> 0 then
            errDescription = err.Description
            on error goto 0
            err.raise GeneralError, "Load", "Could not load MSXML2: " & errDescription
        end if
        on error goto 0
            
        err.Clear
        on error resume next
        m_doc.async = false
        m_doc.load(xmlFile)
        if err.number <> 0 then
            errDescription = err.Description
            on error goto 0
            err.raise GeneralError, "Load", "Error loading xml file: " & xmlFile & ": " & errDescription
        end if
        on error goto 0
    end sub
    
    public function SelectSingleExistingNode(byval xPath)
        dim ret
        set ret = m_doc.selectSingleNode(xPath)
        if ret is nothing then
            err.raise GeneralError, "SelectSingleExistingNode", "Node not found: " & xPath
        end if
        
        set SelectSingleExistingNode = ret
    end function
    
    private sub class_initialize()
        set m_doc = nothing
    end sub
end class

'''<summary>
''Wraps SCC access
'''</summary>
'''<remarks>Currently assumes SourceSafe</remarks>
class SCCAccess
    private m_db
    
    public sub OpenRepository(byval sccRepository, byval sccUser, byval sccPassword)
        set m_db = createobject("SourceSafe")
        
        err.Clear
        on error resume next
        m_db.Open sccRepository, sccUser, sccPassword
        if err.number <> 0 then
            dim errDescription: errDescription = err.Description
            on error goto 0
            err.Raise GeneralError, "OpenRepository", "Could not open ssdb: " & sccRepository & " (user " & sccUser & "): " & errDescription
        end if      
        on error goto 0
    end sub
    
    public sub GetLatestFile(byval osFilePath)
        const VSSFLAG_USERRONO = 1
        const VSSFLAG_USERROYES = 2
        const VSSFLAG_TIMENOW = 4
        const VSSFLAG_TIMEMOD = 8
        const VSSFLAG_TIMEUPD = 12
        const VSSFLAG_EOLCR = 16
        const VSSFLAG_EOLLF = 32
        const VSSFLAG_EOLCRLF = 48
        const VSSFLAG_REPASK = 64
        const VSSFLAG_REPREPLACE = 128
        const VSSFLAG_REPSKIP = 192
        const VSSFLAG_REPMERGE = 256
        const VSSFLAG_CMPFULL = 512
        const VSSFLAG_CMPTIME = 1024
        const VSSFLAG_CMPCHKSUM = 1536
        const VSSFLAG_CMPFAIL = 2048
        const VSSFLAG_RECURSNO = 4096
        const VSSFLAG_RECURSYES = 8192
        const VSSFLAG_FORCEDIRNO = 16384
        const VSSFLAG_FORCEDIRYES = 32768
        const VSSFLAG_KEEPNO = 65536
        const VSSFLAG_KEEPYES = 131072
        const VSSFLAG_DELNO = 262144
        const VSSFLAG_DELYES = 524288
        const VSSFLAG_DELNOREPLACE = 786432
        const VSSFLAG_BINTEST = 1048576
        const VSSFLAG_BINBINARY = 2097152
        const VSSFLAG_BINTEXT = 3145728
        const VSSFLAG_DELTAYES = 4194304
        const VSSFLAG_DELTANO = 8388608
        const VSSFLAG_UPDASK = 16777216
        const VSSFLAG_UPDUPDATE = 33554432
        const VSSFLAG_UPDUNCH = 50331648
        const VSSFLAG_GETYES = 67108864
        const VSSFLAG_GETNO = 134217728
        const VSSFLAG_CHKEXCLUSIVEYES = 268435456
        const VSSFLAG_CHKEXCLUSIVENO = 536870912
        const VSSFLAG_HISTIGNOREFILES = 1073741824

        dim find: find = MapToVSSLoc(osFilePath)
        dim sccpathToUse: sccpathToUse = "$" & Mid(Replace(osFilePath, "\", "/"), find)
        
        err.Clear
        on error resume next
        dim item: set item = m_db.VSSItem(sccpathToUse, false)
        dim errDescription
        if err.number <> 0 then
            errDescription = err.Description
            on error goto 0
            err.Raise GeneralError, "GetLatestFile", "VSSItem failed with: " & sccpathToUse & " (" & errDescription & ")"
        end if
        on error goto 0
        if item is nothing then
            err.Raise GeneralError, "GetLatestFile", "VSSItem failed with: " & sccpathToUse
        end if
        
        dim flags: flags = 0
        flags = flags + VSSFLAG_TIMEMOD 'File-time of checked-in file is what's used (vs. Checkin or checkout time)
        flags = flags + VSSFLAG_CMPCHKSUM 'File-checksum used to determine when delta (get required)
        flags = flags + VSSFLAG_FORCEDIRNO 'Don't use SS working dirs, use OS current-dir instead (req'd for recursive operation)
        flags = flags + VSSFLAG_USERROYES
        flags = flags + VSSFLAG_REPSKIP 'Skip any writable files (checked-out or otherwise writable)

        err.Clear
        on error resume next
        item.Get CStr(osFilePath), flags
        if err.number <> 0 then
            errDescription = err.Description
            on error goto 0
            err.Raise GeneralError, "GetLatestFile", "Item.Get failed with: " & osFilePath & " (" & errDescription & ")"
        end if
        on error goto 0
    end sub    
    
    public function Files(osFolderPath)
        const VSSITEM_PROJECT = 0
        const VSSITEM_FILE = 1
    
        dim find: find = MapToVSSLoc(osFolderPath)
        dim sccpathToUse: sccpathToUse = "$" & Mid(Replace(osFolderPath, "\", "/"), find)

        dim ret: set ret = CreateObject("Scripting.Dictionary")

        err.Clear
        on error resume next
        dim item: set item = m_db.VSSItem(sccpathToUse, false)
        dim errDescription
        if err.number <> 0 then
            errDescription = err.Description
            on error goto 0
            err.Raise GeneralError, "GetLatestFile", "VSSItem failed with: " & sccpathToUse & " (" & errDescription & ")"
        end if
        on error goto 0
        if item is nothing then
            err.Raise GeneralError, "GetLatestFile", "VSSItem failed with: " & sccpathToUse
        end if
        
        dim sccItem
        for each sccItem in item.Items(false) 'false = includeDeleted
            if sccItem.Type = VSSITEM_FILE Then
                ret.Add LCase(sccItem.Name), sccItem.Spec       
            End If
        Next
        
        set Files = ret
    end function
    
    private function GetRootFoldersList()
        const VSSITEM_PROJECT = 0
        const VSSITEM_FILE = 1

        dim sccpathToUse: sccpathToUse = "$/"
        dim ret: set ret = CreateObject("Scripting.Dictionary")

        err.Clear
        on error resume next
        dim item: set item = m_db.VSSItem(sccpathToUse, false)
        dim errDescription
        if err.number <> 0 then
            errDescription = err.Description
            on error goto 0
            err.Raise GeneralError, "GetLatestFile", "VSSItem failed with: " & sccpathToUse & " (" & errDescription & ")"
        end if
        on error goto 0
        if item is nothing then
            err.Raise GeneralError, "GetLatestFile", "VSSItem failed with: " & sccpathToUse
        end if
        
        dim sccItem
        for each sccItem in item.Items(false) 'false = includeDeleted
            if sccItem.Type = VSSITEM_PROJECT Then
                ret.Add LCase(sccItem.Name), sccItem.Spec       
            End If
        Next
        
        set GetRootFoldersList = ret
    end function
    
    private function MapToVSSLoc(byval curDir)
        '1) Find all matches. If only 1, done.
        '2) If > 1, explore leftmost matches first
        'NOTE: Does not work with $/ (there must be some $/DIR)
        
        dim min: min = 9999

        dim foundMatch: foundMatch = false 'default
        dim topLevSccFolder
        for each topLevSccFolder in GetRootFoldersList().Keys
            dim ix: ix = LeftMostDirMatch(topLevSccFolder, curDir)
            if ix >= 1 then '? Match success
                foundMatch = true
                if ix < min then
                    min = ix
                end if
            end if            
        next

        if not foundMatch then
            err.Raise GeneralError, "MapToVSSLoc", "Could not map to vss path: " + curDir
        end if
        
        MapToVSSLoc = min
    end function    
    
    private function LeftMostDirMatch(byval topLevSccFolder, byval curDir)  
        dim curDirToUse: curDirToUse = Replace(LCase(curDir), "\", "/")
        if Mid(curDirToUse, Len(curDirToUse), 1) <> "/" then
            curDirToUse = curDirToUse & "/" 'ensure trailing dirSep suffix
        end if            
        
        dim searchDirToUse: searchDirToUse = "/" & LCase(topLevSccFolder) & "/"
        
        LeftMostDirMatch = InStr(curDirToUse, searchDirToUse)
    end function        

    private sub class_initialize()
        set m_db = nothing
    end sub
end class
