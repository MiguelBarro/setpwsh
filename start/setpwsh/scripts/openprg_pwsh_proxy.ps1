# openprg_pwsh_proxy.ps1
# Script that allows:
# • common vim9 utils → g:Openprg
# • netrw plugin → g:netrw_browsex_viewer 
# to open files in the associated program according to Windows OS criteria.
# It is equivalent to ShellExecute function in Windows API.

if (!$IsWindows)
{
    throw "This script is intended for Windows only."
}

if ($PSEdition -eq "Desktop")
{
    $cmdline = [System.Environment]::CommandLine
}
else
{
    $cmdline = (Get-Process -Pid $pid).CommandLine
}

if ($cmdline -match "$($MyInvocation.MyCommand.Name)\s+(`"?)(.*)\1")
{
    $filename = $matches[2]
    Start-Process -Verb Open -FilePath $filename
}
