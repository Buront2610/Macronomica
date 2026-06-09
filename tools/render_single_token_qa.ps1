param(
    [Parameter(Mandatory = $true)]
    [string] $TokenName
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$repo = Resolve-Path (Join-Path $PSScriptRoot "..")
$inputPath = Join-Path $repo "assets\ui\tokens\$TokenName.png"
$outputDir = Join-Path $repo "docs\assets\uiux\qa"
$outputPath = Join-Path $outputDir "token-$TokenName-single-check.png"

function Test-GoldRimPixel {
    param([System.Drawing.Color] $Color)

    if ($Color.A -lt 20) {
        return $false
    }
    return $Color.R -gt 85 -and $Color.G -gt 55 -and $Color.R -gt ($Color.B + 25) -and $Color.G -gt ($Color.B + 10)
}

function Measure-Bounds {
    param(
        [System.Drawing.Bitmap] $Bitmap,
        [scriptblock] $Predicate
    )

    $minX = $Bitmap.Width
    $minY = $Bitmap.Height
    $maxX = -1
    $maxY = -1
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            if (& $Predicate $Bitmap.GetPixel($x, $y)) {
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

$bitmap = [System.Drawing.Bitmap]::new($inputPath)
try {
    $scale = 4
    $labelH = 80
    $canvas = [System.Drawing.Bitmap]::new($bitmap.Width * $scale, $bitmap.Height * $scale + $labelH)
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    try {
        $graphics.Clear([System.Drawing.Color]::FromArgb(18, 18, 16))
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        $graphics.DrawImage($bitmap, 0, 0, $bitmap.Width * $scale, $bitmap.Height * $scale)

        $gold = Measure-Bounds $bitmap { param($c) Test-GoldRimPixel $c }
        $alpha = Measure-Bounds $bitmap { param($c) $c.A -gt 12 }
        $targetX = ($bitmap.Width - 1) / 2.0
        $targetY = ($bitmap.Height - 1) / 2.0

        $red = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(230, 235, 61, 67), 2)
        $cyan = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(230, 45, 205, 255), 2)
        $green = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(230, 72, 225, 116), 2)
        $goldBox = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(170, 45, 205, 255), 2)
        $alphaBox = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(170, 72, 225, 116), 2)

        $graphics.DrawLine($red, [float]($targetX * $scale), 0, [float]($targetX * $scale), [float]($bitmap.Height * $scale))
        $graphics.DrawLine($red, 0, [float]($targetY * $scale), [float]($bitmap.Width * $scale), [float]($targetY * $scale))

        if ($gold -ne $null) {
            $graphics.DrawRectangle($goldBox, [float]($gold.MinX * $scale), [float]($gold.MinY * $scale), [float](($gold.MaxX - $gold.MinX + 1) * $scale), [float](($gold.MaxY - $gold.MinY + 1) * $scale))
            $graphics.DrawLine($cyan, [float]($gold.CenterX * $scale), 0, [float]($gold.CenterX * $scale), [float]($bitmap.Height * $scale))
            $graphics.DrawLine($cyan, 0, [float]($gold.CenterY * $scale), [float]($bitmap.Width * $scale), [float]($gold.CenterY * $scale))
        }
        if ($alpha -ne $null) {
            $graphics.DrawRectangle($alphaBox, [float]($alpha.MinX * $scale), [float]($alpha.MinY * $scale), [float](($alpha.MaxX - $alpha.MinX + 1) * $scale), [float](($alpha.MaxY - $alpha.MinY + 1) * $scale))
            $graphics.DrawLine($green, [float]($alpha.CenterX * $scale), 0, [float]($alpha.CenterX * $scale), [float]($bitmap.Height * $scale))
            $graphics.DrawLine($green, 0, [float]($alpha.CenterY * $scale), [float]($bitmap.Width * $scale), [float]($alpha.CenterY * $scale))
        }

        $font = [System.Drawing.Font]::new("Consolas", 13)
        $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::Wheat)
        $goldText = "gold dx/dy=n/a"
        $alphaText = "alpha dx/dy=n/a"
        if ($gold -ne $null) {
            $goldText = "gold dx/dy={0:N1},{1:N1} margins L/R/T/B={2}/{3}/{4}/{5}" -f ($gold.CenterX - $targetX), ($gold.CenterY - $targetY), $gold.MinX, ($bitmap.Width - 1 - $gold.MaxX), $gold.MinY, ($bitmap.Height - 1 - $gold.MaxY)
        }
        if ($alpha -ne $null) {
            $alphaText = "alpha dx/dy={0:N1},{1:N1} margins L/R/T/B={2}/{3}/{4}/{5}" -f ($alpha.CenterX - $targetX), ($alpha.CenterY - $targetY), $alpha.MinX, ($bitmap.Width - 1 - $alpha.MaxX), $alpha.MinY, ($bitmap.Height - 1 - $alpha.MaxY)
        }
        $graphics.DrawString("$TokenName  red=image center cyan=gold rim green=alpha silhouette", $font, $brush, 8, $bitmap.Height * $scale + 6)
        $graphics.DrawString($goldText, $font, $brush, 8, $bitmap.Height * $scale + 30)
        $graphics.DrawString($alphaText, $font, $brush, 8, $bitmap.Height * $scale + 54)
    }
    finally {
        $graphics.Dispose()
    }

    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
    $canvas.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output $outputPath
}
finally {
    $bitmap.Dispose()
    if ($canvas -ne $null) {
        $canvas.Dispose()
    }
}
