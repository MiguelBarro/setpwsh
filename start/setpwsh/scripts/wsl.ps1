function Invoke-WSL
{   
    # Translate paths
    $wslargs = @()
        $args | ForEach-Object {
            if( $_ -match "^[A-Z]:.*" )
            {
                $wslargs += wsl -e wslpath $_
            }
            else
            {
                $wslargs += $_
            }
        }

    wsl --exec @wslargs 
}
