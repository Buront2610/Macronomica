$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$repo = Resolve-Path (Join-Path $PSScriptRoot "..")
$tokenDirs = @(
    (Join-Path $repo "assets\ui\tokens"),
    (Join-Path $repo "assets\ui\tokens\small")
)

function Test-GoldRimPixel {
    param([System.Drawing.Color] $Color)

    if ($Color.A -lt 20) {
        return $false
    }
    return $Color.R -gt 85 -and $Color.G -gt 55 -and $Color.R -gt ($Color.B + 25) -and $Color.G -gt ($Color.B + 10)
}

function Measure-GoldRim {
    param([System.Drawing.Bitmap] $Bitmap)

    $minX = $Bitmap.Width
    $minY = $Bitmap.Height
    $maxX = -1
    $maxY = -1
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            if (Test-GoldRimPixel $Bitmap.GetPixel($x, $y)) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    if ($maxX -lt $minX -or $maxY -lt $minY) {
        return $null
    }
    return [pscustomobject]@{
        MinX = $minX
        MinY = $minY
        MaxX = $maxX
        MaxY = $maxY
        CenterX = ($minX + $maxX) / 2.0
        CenterY = ($minY + $maxY) / 2.0
    }
}

function Move-Bitmap {
    param(
        [System.Drawing.Bitmap] $Bitmap,
        [int] $Dx,
        [int] $Dy
    )

    $copy = [System.Drawing.Bitmap]::new($Bitmap.Width, $Bitmap.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($copy)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $graphics.DrawImageUnscaled($Bitmap, $Dx, $Dy)
    $graphics.Dispose()
    return $copy
}

$changed = @()
foreach ($dir in $tokenDirs) {
    $files = Get-ChildItem -Path $dir -Filter "*.png" |
        Where-Object { $_.Name -ne "macronomica_token_atlas.png" } |
        Sort-Object Name
    foreach ($file in $files) {
        $bitmap = [System.Drawing.Bitmap]::new($file.FullName)
        try {
            $rim = Measure-GoldRim $bitmap
            if ($rim -eq $null) {
                continue
            }
            $targetX = ($bitmap.Width - 1) / 2.0
            $targetY = ($bitmap.Height - 1) / 2.0
            $deltaX = $rim.CenterX - $targetX
            $deltaY = $rim.CenterY - $targetY
            $dx = if ($deltaX -lt -0.5) { 1 } elseif ($deltaX -gt 0.5) { -1 } else { 0 }
            $dy = if ($deltaY -lt -0.5) { 1 } elseif ($deltaY -gt 0.5) { -1 } else { 0 }
            if ($dx -ne 0 -or $dy -ne 0) {
                $nudged = Move-Bitmap -Bitmap $bitmap -Dx $dx -Dy $dy
                $bitmap.Dispose()
                $nudged.Save($file.FullName, [System.Drawing.Imaging.ImageFormat]::Png)
                $nudged.Dispose()
                $changed += "$(Resolve-Path -Relative $file.FullName) dx=$dx dy=$dy"
                $bitmap = $null
            }
        }
        finally {
            if ($bitmap -ne $null) {
                $bitmap.Dispose()
            }
        }
    }
}

if ($changed.Count -eq 0) {
    Write-Output "No token output nudge needed."
} else {
    Write-Output "Nudged token outputs:"
    $changed | ForEach-Object { Write-Output $_ }
}
