# vim_pwsh_proxy.ps1
# Expects:
#   set shell=powershell (or set shell=pwsh)
#   let &shellcmdflag="-NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -File \"" . s:auxshellscriptname . '"' 
#   set shellquote=
#   set shellxquote=(
#   set shellredir=>%s

try
{
    # Check encoding
    $encoding = switch ($Env:setpwsh_encoding)
    {
        "ascii" {'$OutputEncoding = New-Object System.Text.ASCIIEncoding;'}
        "utf7" {'$OutputEncoding = New-Object System.Text.UTF7Encoding;'}
        "utf32" {'$OutputEncoding = New-Object System.Text.UTF32Encoding;'}
        "unicode" {'$OutputEncoding = New-Object System.Text.UnicodeEncoding;'}
        default
        {
            $Env:setpwsh_encoding = "utf8"
            '$OutputEncoding = New-Object System.Text.UTF8Encoding;'
        }
    }

    $encoding += '[Console]::InputEncoding = $OutputEncoding;' 
    $encoding += '[Console]::OutputEncoding = $OutputEncoding;' 
    $encoding += '$PSDefaultParameterValues["*:Encoding"] = "{0}";' -f $Env:setpwsh_encoding 

    Invoke-Expression -Command $encoding

    # Retrieve command line
    $proc = Get-Process -Pid $pid

    if ($PSEdition -eq "Desktop")
    {
        $cmdline = [System.Environment]::CommandLine
    }
    else
    {
        $cmdline = $proc.CommandLine
    }

    if ($cmdline -match "\(& {(?<cat>.*) \| & (?<cmd>.*)}(?<redir>.*)\)$")
    {
        $cat = $matches.cat
        $cmd = $matches.cmd
        $redir = $matches.redir

        $cmd | Select-String -Pattern '{(?:(?<o>{)|[^{}])*(?:(?<-o>})|[^{}])*}' -AllMatches |
               Select-Object -ExpandProperty Matches | Sort-Object -Descending Index |
               ForEach-Object { $res = $cmd } { $res = $res.Remove($_.Index, $_.Length) }

        $is_pipe = $res -match '\$_\b'
        $is_input = $res -match '\$input\b'

        if ($is_pipe)
        { # execute expression per-line
            $cmd = $cat + " | % { " + $cmd + " } " + $redir
        }
        elseif ($is_input)
        { # use script object to enable $input
            $cmd = $cat + " | & { " + $cmd + " } " + $redir
        }
        else
        { # send in bulk
            $cmd = $cat + " | " + $cmd + " " + $redir
        }

        Invoke-Expression -Command $cmd
    }
    else
    {
        if ($cmdline -match "\((?<cmd>.*)(?<redir> >.*)\)$")
        {
            $cmd = $matches.cmd
            $redir = $matches.redir
        }
        elseif ($cmdline -match "\((?<cmd>.*)\)$")
        {
            $cmd = $matches.cmd
        }
        else
        {
            throw "unexpected cmdline: $cmdline"
        }

        # trimming external parenthesis (interfere with pwsh redirection)
        while ($cmd -match "\s*\((?<cmd>.*)\)\s*$")
        {
            $cmd = $matches.cmd
        }

        if ($redir)
        {
            $cmd += $redir
        }

        # allow stdin forwarding under binary demand
        $b64_cmd = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($encoding + $cmd))
        & $proc.ProcessName -NoLogo -NoProfile -ExecutionPolicy Bypass `
                            -NonInteractive -EncodedCommand $b64_cmd
    }
}
catch
{
    $_.ToString()
}
