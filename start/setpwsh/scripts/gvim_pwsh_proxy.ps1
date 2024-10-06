# gvim_pwsh_proxy.ps1
# Expects
#   set shell=powershell (or set shell=pwsh)
#   let &shellcmdflag="-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File gvim_pwsh_proxy.ps1
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
        $indec = '$PSStyle.OutputRendering = "PlainText";'
    }

    $outdec = "2>&1 | Out-String -Stream"
    $filter = $cmdline -match "\(\(.*\)\)$"
    if ($filter) { $offset = 2 } else { $offset = 1 } # desktop version lacks ternary operator ?:
    $cmd = $cmdline.SubString($cmdline.IndexOf("(") + $offset)
    $cmd = $cmd.SubString(0, $cmd.Length - $offset)

    $cmd | Select-String -Pattern '{(?:(?<o>{)|[^{}])*(?:(?<-o>})|[^{}])*}' -AllMatches |
           Select-Object -ExpandProperty Matches | Sort-Object -Descending Index |
           ForEach-Object { $res = $cmd } { $res = $res.Remove($_.Index, $_.Length) }

    $is_pipe = $res -match '\$_\b'
    $is_input = $res -match '\$input\b'

    if ($filter -or $is_input -or $is_pipe)
    {
        if ($is_pipe)
        {   # stdin capture
            $cmd = "$indec `$input | % { $cmd } $outdec"
        }
        else
        {   # up to the user the stdin capture
            $cmd = "$indec $cmd $outdec"
        }

        $b64_cmd = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($encoding + $cmd))
        & $proc.ProcessName -NoLogo -NoProfile -ExecutionPolicy ByPass `
                            -NonInteractive -EncodedCommand $b64_cmd 2>$null
    }
    else
    {   
        # $cmd = "$indec $cmd $outdec"
        $cmd = "$indec $cmd $outdec"
        # no stdin capture
        Invoke-Expression -Command $cmd -ErrorAction Stop
    }
}
catch
{
    $_.ToString()
}
