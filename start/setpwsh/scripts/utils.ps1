function Remove-ExternalParenthesis
{
    param ( [string]$Expression)

    $levels = @{}
    $icmd = $Expression
    $iteration = -1

    # Extract all parenthesis groups
    while ($icmd -match "[\(\)]+")
    {
        $iteration += 1
        $ms = Select-String -InputObject $icmd -AllMatches -Pattern "\(([^\(\)]*)\)"
        $levels[$iteration] = $ms.Matches
        $chars = $icmd.ToCharArray()
        foreach ($m in $ms.Matches)
        {
            foreach ($index in (1..$m.Length).foreach{ $_ + $m.Index -1})
            {
                $chars[$index] = 'X'
            }
        }
        $icmd = -join $chars
    }

    # Select the best match
    $sel = $null
    foreach ($level in $iteration..0)
    {
        $m = $levels[$level]
        if ($m.Count -eq 1)
        {
            $discarded = $Expression.Remove($m[0].Index, $m[0].Length)
            if ($discarded -match "^[\(\)\s]*$")
            {
                $sel = $m[0]
            }
        }
        else
        {
            # More than one parenthesis in a level ... we are done
            break
        }
    }

    if ($sel)
    {
        $Expression = $Expression.substring($sel.Index + 1, $sel.Length - 2)
    }

    return $Expression
}
