$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$repo = Resolve-Path (Join-Path $PSScriptRoot "..")
$tokenDirs = @(
    @{ Path = Join-Path $repo "assets\ui\tokens"; MinimumEdge = 10; MaxDelta = 0.6; Label = "full-size" },
    @{ Path = Join-Path $repo "assets\ui\tokens\small"; MinimumEdge = 2; MaxDelta = 0.6; Label = "small" }
)

function Test-GoldRimPixel {
    param([System.Drawing.Color] $Color)

    if ($Color.A -lt 20) {
        return $false
    }
    return $Color.R -gt 85 -and $Color.G -gt 55 -and $Color.R -gt ($Color.B + 25) -and $Color.G -gt ($Color.B + 10)
}

$failures = @()
$stats = @()
foreach ($entry in $tokenDirs) {
    $files = Get-ChildItem -Path $entry.Path -Filter "*.png" |
        Where-Object { $_.Name -ne "macronomica_token_atlas.png" } |
        Sort-Object Name
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
            $relative = Resolve-Path -Relative $file.FullName
            if ($maxX -lt $minX -or $maxY -lt $minY) {
                $failures += "$relative`: no gold rim detected"
                continue
            }

            $centerX = ($minX + $maxX) / 2.0
            $centerY = ($minY + $maxY) / 2.0
            $targetX = ($bitmap.Width - 1) / 2.0
            $targetY = ($bitmap.Height - 1) / 2.0
            $dx = $centerX - $targetX
            $dy = $centerY - $targetY
            $edge = [Math]::Min([Math]::Min($minX, $minY), [Math]::Min($bitmap.Width - 1 - $maxX, $bitmap.Height - 1 - $maxY))
            $stats += [pscustomobject]@{
                Set = $entry.Label
                File = $relative
                DeltaX = [Math]::Abs($dx)
                DeltaY = [Math]::Abs($dy)
                Edge = $edge
            }
            if ([Math]::Abs($dx) -gt $entry.MaxDelta -or [Math]::Abs($dy) -gt $entry.MaxDelta -or $edge -lt $entry.MinimumEdge) {
                $failures += "$relative`: rim center delta=($([Math]::Round($dx, 1)), $([Math]::Round($dy, 1))) edge=$edge"
            }
        }
        finally {
            $bitmap.Dispose()
        }
    }
}

if ($failures.Count -gt 0) {
    throw "Token validation failed:`n$($failures -join "`n")"
}

$maxDeltaX = ($stats | Measure-Object -Property DeltaX -Maximum).Maximum
$maxDeltaY = ($stats | Measure-Object -Property DeltaY -Maximum).Maximum
$minEdge = ($stats | Measure-Object -Property Edge -Minimum).Minimum
Write-Output "Token validation passed: $($stats.Count) icons, max rim delta=($([Math]::Round($maxDeltaX, 2)), $([Math]::Round($maxDeltaY, 2))), min edge=$minEdge."
