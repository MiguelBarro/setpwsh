function Remove-ExternalParenthesis
{
    param ( [string]$Expression)

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Expression, [ref]$tokens, [ref]$errors)

    if ($errors)
    {
        Write-Error $errors
        return $Expression
    }

    # filter out unnecessary tokens
    $bracketTokens = $tokens | ? {
        $_.Kind -eq [System.Management.Automation.Language.TokenKind]::LParen -or
        $_.Kind -eq [System.Management.Automation.Language.TokenKind]::RParen
        } | Sort-Object { $_.Extent.StartOffset }

    # Map matching brackets
    $bracketStack = @()
    $bracketMap = @{}

    foreach ($token in $bracketTokens) {
        $tokenPos = $token.Extent.StartOffset

        if ($token.Kind -eq [System.Management.Automation.Language.TokenKind]::LParen) {
            # Opening bracket - push to stack
            $bracketStack += $tokenPos
        }
        elseif ($token.Kind -eq [System.Management.Automation.Language.TokenKind]::RParen) {
            # Closing bracket - pop from stack and create mapping
            if ($bracketStack.Count -gt 0) {
                $matchingOpen = $bracketStack[-1]
                switch ($bracketStack.Count) {
                    1 { $bracketStack = @() }
                    2 { $bracketStack = @($bracketStack[0]) }
                    default { $bracketStack = $bracketStack[0..($bracketStack.Count-2)] }
                }

                # Create mapping
                $bracketMap[$matchingOpen] = $tokenPos
            }
        }
    }


    $sel = $null
    foreach ($key in ($bracketMap.keys | sort))
    {
        if ($Expression.Remove($key, $bracketMap[$key] - $key + 1) -match "^[\(\)\s]*$")
        { # valid external brackets
            $sel = $key
        }
        else
        { # only inner brackets beyond
            break
        }
    }

    # return the contents of the smaller external parentheses
    if ($sel -ne $null)
    {
        $Expression = $Expression.substring($sel + 1, $bracketMap[$sel] - $sel - 1)
    }

    return $Expression
}
