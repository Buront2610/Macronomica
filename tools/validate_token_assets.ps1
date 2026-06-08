$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$repo = Resolve-Path (Join-Path $PSScriptRoot "..")
$tokenDir = Join-Path $repo "assets\ui\tokens"
$files = Get-ChildItem -Path $tokenDir -Filter "*.png" |
    Where-Object { $_.Name -ne "macronomica_token_atlas.png" } |
    Sort-Object Name

function Test-GoldRimPixel {
    param([System.Drawing.Color] $Color)

    if ($Color.A -lt 20) {
        return $false
    }
    return $Color.R -gt 85 -and $Color.G -gt 55 -and $Color.R -gt ($Color.B + 25) -and $Color.G -gt ($Color.B + 10)
}

$failures = @()
foreach ($file in $files) {
    $bitmap = [System.Drawing.Bitmap]::new($file.FullName)
    try {
        $minX = $bitmap.Width
        $minY = $bitmap.Height
        $maxX = -1
        $maxY = -1
        for ($y = 0; $y -lt $bitmap.Height; $y++) {
            for ($x = 0; $x -lt $bitmap.Width; $x++) {
                if (Test-GoldRimPixel $bitmap.GetPixel($x, $y)) {
                    if ($x -lt $minX) { $minX = $x }
                    if ($x -gt $maxX) { $maxX = $x }
                    if ($y -lt $minY) { $minY = $y }
                    if ($y -gt $maxY) { $maxY = $y }
                }
            }
        }
        if ($maxX -lt $minX -or $maxY -lt $minY) {
            $failures += "$($file.Name): no gold rim detected"
            continue
        }

        $centerX = ($minX + $maxX) / 2.0
        $centerY = ($minY + $maxY) / 2.0
        $targetX = ($bitmap.Width - 1) / 2.0
        $targetY = ($bitmap.Height - 1) / 2.0
        $dx = $centerX - $targetX
        $dy = $centerY - $targetY
        $edge = [Math]::Min([Math]::Min($minX, $minY), [Math]::Min($bitmap.Width - 1 - $maxX, $bitmap.Height - 1 - $maxY))
        if ([Math]::Abs($dx) -gt 1.0 -or [Math]::Abs($dy) -gt 1.0 -or $edge -lt 12) {
            $failures += "$($file.Name): rim center delta=($([Math]::Round($dx, 1)), $([Math]::Round($dy, 1))) edge=$edge"
        }
    }
    finally {
        $bitmap.Dispose()
    }
}

if ($failures.Count -gt 0) {
    throw "Token validation failed:`n$($failures -join "`n")"
}

Write-Output "Token validation passed: $($files.Count) coin tokens are centered and unclipped."
