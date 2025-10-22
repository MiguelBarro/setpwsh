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
        "utf32" {'$OutputEncoding = New-Object System.Text.UTF32Encoding (,$false);'}
        "unicode" {'$OutputEncoding = New-Object System.Text.UnicodeEncoding (,$false);'}
        default
        {
            # In pwsh core, the default encoding is utf8NoBOM
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
        $indec = '$PSStyle.OutputRendering = "PlainText";'
    }

    $outdec = "2>&1 | Out-String -Stream"
    $filter = $cmdline -match "\(\(.*\)\)$"
    if ($filter) { $offset = 2 } else { $offset = 1 } # desktop version lacks ternary operator ?:
    $cmd = $cmdline.SubString($cmdline.IndexOf("(") + $offset)
    $cmd = $cmd.SubString(0, $cmd.Length - $offset)

    # Check for redirection
    if ($cmd -match '>(\S*)$')
    {
        $redir_file = $matches[1]
    }
    else
    {
        $outdec = "2>&1 | Out-String -Stream"
    }

    $cmd | Select-String -Pattern '{(?:(?<o>{)|[^{}])*(?:(?<-o>})|[^{}])*}' -AllMatches |
           Select-Object -ExpandProperty Matches | Sort-Object -Descending Index |
           ForEach-Object { $res = $cmd } { $res = $res.Remove($_.Index, $_.Length) }

    $is_pipe = $res -match '\$_\b'
    $is_input = $res -match '\$input\b'

    if ($filter -or $is_input -or $is_pipe)
    {
        $preference = '$ErrorActionPreference = "Stop";'
        $propagate_error = '; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }'

        if ($is_pipe)
        {   # stdin capture
            $cmd = "$indec `$input | % { $cmd } $propagate_error $outdec"
        }
        else
        {   # up to the user the stdin capture
            $cmd = "$indec $cmd $propagate_error $outdec"
        }

        $plain_cmd = $encoding + $preference + $cmd
        $b64_cmd = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($plain_cmd))
        & $proc.ProcessName -NoLogo -NoProfile -ExecutionPolicy ByPass `
                            -NonInteractive -EncodedCommand $b64_cmd 2>$null
    }
    else
    {   
        $cmd = "$indec $cmd $outdec"
        # no stdin capture
        $ErrorActionPreference = "Stop"
        Invoke-Expression -Command $cmd
    }

    # Unlike powershell core, BOM emission on redirection cannot be disabled for Desktop edition.
    if ($PsVersionTable.PSEdition -eq "Desktop" -and $redir_file -ne $null)
    {
        # Remove BOM
        if (Test-Path -Path $redir_file)
        {
            $BOM = @(0xef, 0xbb, 0xbf, 0xff, 0xfe, 0x00, 0x2b, 0x2f, 0x76)
            $content = Get-Content -Path $redir_file -Raw -Encoding Byte
            if ($content)
            {
                # identify BOM
                $Length = 0
                $content[0..3] | ForEach-Object { if ($_ -in $BOM) { $Length++ } }
                # ignore it
                $content | Select-Object -Skip $Length |
                    Set-Content -Path $redir_file -Encoding Byte
            }
        }         
    }

    # propagate error level
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
catch
{
    $_.ToString()
    exit 1
}
