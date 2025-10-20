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
        "utf32" {'$OutputEncoding = New-Object System.Text.UTF32Encoding (,$false);'}
        "unicode" {'$OutputEncoding = New-Object System.Text.UnicodeEncoding (,$false);'}
        default
        {
            if ($PsVersionTable.PSEdition -eq "Core")
            { $Env:setpwsh_encoding = "utf8NoBOM" } else
            { $Env:setpwsh_encoding = "utf8" }
            '$OutputEncoding = New-Object System.Text.UTF8Encoding $false;'
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

        $ErrorActionPreference = "Stop"
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

    # Unlike powershell core, BOM emission on redirection cannot be disabled for Desktop edition.
    if ($PsVersionTable.PSEdition -eq "Desktop" -and $redir -ne $null)
    {
        # Remove BOM
        # retrieve redirection file
        $file = $redir -replace '^\s*>+\s*', ''
        if (Test-Path -Path $file)
        {
            $BOM = @(0xef, 0xbb, 0xbf, 0xff, 0xfe, 0x00, 0x2b, 0x2f, 0x76)
            $content = Get-Content -Path $file -Raw -Encoding Byte
            if ($content)
            {
                # identify BOM
                $Length = 0
                $content[0..3] | ForEach-Object { if ($_ -in $BOM) { $Length++ } }
                # ignore it
                $content | Select-Object -Skip $Length |
                    Set-Content -Path $file -Encoding Byte
            }
        }         
    }

    # propagate error level
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
catch
{
    Write-Error $_.ToString()
}
