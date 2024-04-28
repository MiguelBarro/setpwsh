# ftp.ps1
# Precondition:
# :let g:netrw_ftp_cmd="$PSScriptRoot/ftp.ps1"
# Several comments:
#  + Note we must execute all statements pipe in on the very same ftp instance. That's the reason why we gathered in the variable $pipeline all the inputs.
#  + The ftp binary is expecting a file like stdin thus we must join the string[] into a single array with newline
#    characters.
#  + Without the quit statement ftp triggers and error.

begin
{
    $pipeline = @()
}
process
{
    if ($_)
    {
        $text = $_
        $pipeline += $text | Select-String -Pattern "([`"']?)[a-zA-Z]:[\w\s\./\\]*\1" -AllMatches |
             Select -ExpandProperty Matches | Sort-Object -Property Index -Descending |
             ForEach-Object { $newtext = $text } {
                if ($_.Value[0] -match "[`"']")
                {
                    $wslpath = wsl -e wslpath (Invoke-Expression $_.Value)
                    $newtext = $newtext.Remove($_.index+1, $_.Length-2).Insert($_.index+1, $wslpath)
                }
                else
                {
                    $wslpath = wsl -e wslpath $_.Value
                    $newtext = $newtext.Remove($_.index, $_.Length).Insert($_.index, $wslpath)
                }

             } { $newtext }
    }
}
end
{
    if ($pipeline)
    {
        ($pipeline + 'quit ') -join "`n" | wsl -e ftp -p $args
    }
    else
    {
        wsl -e ftp -p $args
    }
}
