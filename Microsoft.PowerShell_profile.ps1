# Functions in this and subsequent files are dependent
# on customizations placed in the global 'profile.ps1'
# file. It can be found in:
# %windir%\System32\WindowsPowerShell\v1.0
#Set-StrictMode -Version Latest
$debugPreference = 'Continue'
 
$profile_home =  [System.IO.Path]::GetDirectoryName($profile)
if (!$env:Home) {
	$env:Home = resolve-path $env:HomePath
}
set-location $home

function global:TabExpansion {
  param($line, $lastWord)
  
  if ($line -match 'sslftp'){
    return cat C:\Windows\netrc.txt | Select-String '^machine ' | % { if($_.Line -match "^machine ($lastword\S*)" ){ $matches[1] }}
  }
  if ($line -match 'nant') {
  	nant -projecthelp | &{ begin{$cmd=$false} process{ if ($cmd) {write "$_"} elseif ($_ -match '.*:'){$cmd = $true}
}} | where {$_ -notmatch '^$'} | where {$_ -notmatch '.*:'} | %{$_ -replace ' .*$', ''} | sort | get-unique
  }
}

# set up posh-git:
Import-Module posh-git

$teBackup = 'posh-git_DefaultTabExpansion'
if(!(Test-Path Function:\$teBackup)) {
    Rename-Item Function:\TabExpansion $teBackup
}

# Set up tab expansion and include git expansion
function TabExpansion($line, $lastWord) {
    $lastBlock = [regex]::Split($line, '[|;]')[-1]
    
    switch -regex ($lastBlock) {
        # Execute git tab completion for all git-related commands
        'git (.*)' { GitTabExpansion $lastBlock }
        # Fall back on existing tab expansion
        default { & $teBackup $line $lastWord }
    }
}

Enable-GitColors

# This should go OUTSIDE the prompt function, it doesn't need re-evaluation
# We're going to calculate a prefix for the window title 
# Our basic title is "PoSh - C:\Your\Path\Here" showing the current path
if(!$global:WindowTitlePrefix) {
   # But if you're running "elevated" on vista, we want to show that ...
   if( ([System.Environment]::OSVersion.Version.Major -gt 5) -and ( # Vista and ...
         new-object Security.Principal.WindowsPrincipal (
            [Security.Principal.WindowsIdentity]::GetCurrent()) # current user is admin
            ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) )
   {
      $global:WindowTitlePrefix = "PoS [ADMIN]"
   } else {
      $global:WindowTitlePrefix = "PoS"
   }
}

# $DebugPreference = 'Continue'
function get-aliassuggestion {
	param($lastCommand)
	$helpMatches = @()
	foreach($alias in Get-Alias) {
	  if($lastCommand -match ("\b" + 
	  	[System.Text.RegularExpressions.Regex]::Escape($alias.Definition) + "\b")) {
	  		$helpMatches += "Suggestion: An alias for $($alias.Definition) is $($alias.Name)"
	    }
	}
	$helpMatches
}

# Set up a simple prompt, adding the git prompt parts inside git repos
#function prompt {
#    # Reset color, which can be messed up by Enable-GitColors
#    $Host.UI.RawUI.ForegroundColor = $GitPromptSettings.DefaultForegroundColor
#
#    Write-Host($pwd) -nonewline
#        
#    # Git Prompt
#    $Global:GitStatus = Get-GitStatus
#    Write-GitStatus $GitStatus
#
#    return "> "
#}

function prompt {
   # FIRST, make a note if there was an error in the previous command
   $err = !$?

	$historyItem = Get-History -Count 1

  if($historyItem) {
    $suggestions = @(Get-AliasSuggestion $historyItem.CommandLine)
    if ($suggestions) {
      foreach($aliasSuggestion in $suggestions) {
        Write-Debug "$aliasSuggestion"
      }
      Write-Host ""
    }
  }
  
   # Make sure Windows and .Net know where we are (they can only handle the FileSystem)
   [Environment]::CurrentDirectory = (Get-Location -PSProvider FileSystem).ProviderPath
   # Also, put the path in the title ... (don't restrict this to the FileSystem 
   $Host.UI.RawUI.WindowTitle = "{0} - {1} ({2})" -f $global:WindowTitlePrefix,$pwd.Path,$pwd.Provider.Name
   
   # Determine what nesting level we are at (if any)
   $Nesting = "$([char]0xB7)" * $NestedPromptLevel

   # Generate PUSHD(push-location) Stack level string
   $Stack = "+" * (Get-Location -Stack).count
   
   # my New-Script and Get-PerformanceHistory functions use history IDs
   # So, put the ID of the command in, so we can get/invoke-history easier
   # eg: "r 4" will re-run the command that has [4]: in the prompt
   $nextCommandId = (Get-History -count 1).Id + 1
   # Output prompt string
   # If there's an error, set the prompt foreground to "Red", otherwise, "Yellow"
   if($err) { $fg = "Red" } else { $fg = "Yellow" }
   # Notice: no angle brackets, makes it easy to paste my buffer to the web
   Write-Host (get-location).path  "`n[${Nesting}${nextCommandId}${Stack}]:" -NoNewLine -Fore $fg
   
   return " "
}

function enable-historypersistence {
	Set-StrictMode -Version Latest
	$GLOBAL:maximumHistoryCount = 32767
	$historyFile = (Join-Path (Split-Path $profile) "commandHistory.clixml")
	if(Test-Path $historyFile) {
		write-debug 'importing history'
	  Import-CliXml $historyFile | Add-History
	}
	$null = Register-EngineEvent -SourceIdentifier `
	  ([System.Management.Automation.PsEngineEvent]::Exiting) -Action {
	  	write-debug 'saving history'
	  	$historyFile = (Join-Path (Split-Path $profile) "commandHistory.clixml")
	  	$maximumHistoryCount = 1kb
	  	$oldEntries = @()
	  	if(Test-Path $historyFile) {
	      $oldEntries = Import-CliXml $historyFile -ErrorAction SilentlyContinue
	  	}
	  	$currentEntries = Get-History -Count $maximumHistoryCount
	  	$additions = Compare-Object $oldEntries $currentEntries `
	      -Property CommandLine | Where-Object { $_.SideIndicator -eq "=>" } |
	      Foreach-Object { $_.CommandLine }
	  	$newEntries = $currentEntries | ? { $additions -contains $_.CommandLine }
	  	$history = @($oldEntries + $newEntries) |
	      Sort -Unique -Descending CommandLine | Sort StartExecutionTime
	        Remove-Item $historyFile
	  	$history | Select -Last 100 | Export-CliXml $historyFile
		}    
}
enable-historypersistence

if(test-path -Path env:programw6432)
{
	#. "$bfUser\SharePoint.ps1"
}

# function bf-help()
# {
# 	if($showTP -eq $null)
# 	{
# 		write-host `t'You must first load the Core.ps1 file. This can' -foregroundcolor green
# 		write-host `t'be done by first running the command:' -foregroundcolor green;
# 		write-host `t`t -nonewline;
# 		write-host ' bf-loadCore [' -nonewline -foregroundcolor blue -backgroundcolor Gray;
# 		write-host 'noQualifier:bool' -nonewline -foregroundcolor DarkRed -backgroundcolor Gray;
# 		write-host '] ' -foregroundcolor blue -backgroundcolor Gray;
# 		write-host ' '
# 	}
# 	else
# 	{
# 		$showTPo = $showTP;
# 		$showTP = $true;
# 		
# 		tp -t "Available scripts are:"
# 		#tp -m ". `$bfWin\Core.ps1";
# 		tp -m ". `$bfWin\DebugXtras.ps1";
# 		tp -m ". `$bfWin\Generics.ps1";
# 		tp -m ". `$bfWin\MakeCAB.ps1";
# 		tp -m ". `$bfWin\PickerDialogs.ps1";
# 		tp -m " ";
# 		tp -m ". `$bfUser\CmdRegEdit.ps1";
# 		tp -m ". `$bfUser\SharePoint.ps1";
# 		tp -m ". `$bfUser\WspRegEdit.ps1";
# 		tp -m ". `$bfUser\CmdRegEdit.ps1";
# 		$showTP = $showTPo;
# 	}
# }
# new-alias bfh bf-help;

# set up sql provider (sqlps)
# . "$profile_home/init_sql_provider.ps1"

#new-psdrive -name db -root D:/DB -psprovider filesystem > out-null


function touch {set-content -Path ($args[0]) -Value ($null) }

function ed {
	$tmp_file = "$($env:TEMP)/posh_ed.tmp"
	touch $tmp_file
	get-history | ?{ $_.commandline -ne 'ex' } |
	? { $_.commandline -ne 'ed' } |
	select commandline -last 1 |
	%{ $_.CommandLine} > $tmp_file
	e $tmp_file
}

import-module pscx  -arg @{
	PageHelpUsingLess = $false; 
	TextEditor = 'C:\Program Files (x86)\e\e.exe'
}

function Get-Batchfile ($file) {
    $cmd = "`"$file`" & set"
    cmd /c $cmd | Foreach-Object {
        $p, $v = $_.split('=')
        Set-Item -path env:$p -value $v
    }
}

function VsVars32($version = "9.0")
{
    $key = "HKLM:SOFTWARE\Microsoft\VisualStudio\" + $version
    $VsKey = get-ItemProperty $key
    $VsInstallPath = [System.IO.Path]::GetDirectoryName($VsKey.InstallDir)
    $VsToolsDir = [System.IO.Path]::GetDirectoryName($VsInstallPath)
    $VsToolsDir = [System.IO.Path]::Combine($VsToolsDir, "Tools")
    $BatchFile = [System.IO.Path]::Combine($VsToolsDir, "vsvars32.bat")
    Get-Batchfile $BatchFile
    [System.Console]::Title = "Visual Studio " + $version + " Windows Powershell"
}

<#
.Synopsis
	stop pipeline without processing all objects
.Description
	
.Parameter condition 
	if condition is met, scriptblock is cancelled
    
.Example
	$result = do { 
		Get-EventLog Application | Stop-Pipeline { $_.InstanceID -gt 10000} 
	} while ($false)
	
#>
filter Stop-Pipeline() {
	param([scriptblock]$condition = {$true})
	$_
	if (& $condition) {
		continue
	}
}

$env:Path = "C:/Program Files (x86)/Utilities/git/cmd;$env:Path;C:/Program Files (x86)/nant/bin;C:/Program Files (x86)/Utilities;;"

# add scripting stuff to path
if (test-path ~/scripts) {
	$env:path += ";$(resolve-path '~/scripts/powershell')"
	ls -recurse ~/scripts/powershell | where {$_.mode -match 'd'} | foreach { $env:path += ";$($_.fullname)" }
}

if (test-path sde:/DRS/scripts) {
	$env:path += ";$((resolve-path 'sde:/DRS/scripts').ProviderPath)"
}

new-psdrive -name sde -root C:/Projects/SDE -psprovider filesystem > out-null
new-psdrive -name modules -root C:\Users\jrickerd.BLACKFIN\Documents\WindowsPowerShell\Modules filesystem > out-null
