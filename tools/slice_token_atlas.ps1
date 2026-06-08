$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$repo = Resolve-Path (Join-Path $PSScriptRoot "..")
$atlasPath = Join-Path $repo "assets\ui\tokens\macronomica_token_atlas.png"
$tokenDir = Join-Path $repo "assets\ui\tokens"
$smallDir = Join-Path $tokenDir "small"

New-Item -ItemType Directory -Force -Path $smallDir | Out-Null

$names = @(
    "fiscal_treasury", "central_bank", "trade_port", "industry_factory", "financial_shield", "diplomacy_handshake",
    "reform_wrench", "social_safety_net", "debt_chain", "currency_arrows", "unemployment_people", "inflation_flame",
    "world_demand_globe", "interest_rate_coin", "trade_gate", "financial_storm", "depression_shadow", "protection_wall",
    "coordination_ring", "bureaucrat_seal", "central_bank_staff_seal", "diplomat_seal", "auditor_seal", "lobbyist_seal"
)

function Get-BrightBands {
    param(
        [System.Drawing.Bitmap] $Bitmap,
        [ValidateSet("x", "y")] [string] $Axis,
        [int] $Step = 4,
        [double] $Threshold = 12.0,
        [int] $MinWidth = 80
    )

    $length = if ($Axis -eq "x") { $Bitmap.Width } else { $Bitmap.Height }
    $counts = [int[]]::new($length)

    for ($y = 0; $y -lt $Bitmap.Height; $y += $Step) {
        for ($x = 0; $x -lt $Bitmap.Width; $x += $Step) {
            $color = $Bitmap.GetPixel($x, $y)
            $luma = [int](0.299 * $color.R + 0.587 * $color.G + 0.114 * $color.B)
            $max = [Math]::Max($color.R, [Math]::Max($color.G, $color.B))
            $min = [Math]::Min($color.R, [Math]::Min($color.G, $color.B))
            $chroma = $max - $min
            if ($luma -gt 46 -and ($chroma -gt 12 -or $luma -gt 80)) {
                if ($Axis -eq "x") { $counts[$x]++ } else { $counts[$y]++ }
            }
        }
    }

    $radius = 8
    $smooth = [double[]]::new($length)
    for ($i = 0; $i -lt $length; $i++) {
        $sum = 0
        $n = 0
        for ($j = [Math]::Max(0, $i - $radius); $j -le [Math]::Min($length - 1, $i + $radius); $j++) {
            $sum += $counts[$j]
            $n++
        }
        $smooth[$i] = $sum / $n
    }

    $bands = @()
    $inside = $false
    $start = 0
    for ($i = 0; $i -lt $length; $i++) {
        if (-not $inside -and $smooth[$i] -ge $Threshold) {
            $inside = $true
            $start = $i
        } elseif ($inside -and $smooth[$i] -lt $Threshold) {
            $end = $i - 1
            if ($end - $start + 1 -ge $MinWidth) {
                $bands += ,@($start, $end)
            }
            $inside = $false
        }
    }
    if ($inside) {
        $end = $length - 1
        if ($end - $start + 1 -ge $MinWidth) {
            $bands += ,@($start, $end)
        }
    }

    return $bands
}

function Export-Token {
    param(
        [System.Drawing.Bitmap] $Source,
        [System.Drawing.RectangleF] $Crop,
        [string] $Path,
        [int] $Size
    )

    $out = New-TokenBitmap -Size $Size
    $graphics = New-TokenGraphics -Bitmap $out
    $padding = [Math]::Max(2.0, $Size * 0.04)
    $graphics.DrawImage(
        $Source,
        [System.Drawing.RectangleF]::new($padding, $padding, $Size - $padding * 2.0, $Size - $padding * 2.0),
        $Crop,
        [System.Drawing.GraphicsUnit]::Pixel
    )
    $graphics.Dispose()

    Remove-AtlasBackground -Bitmap $out
    Center-TokenContent -Bitmap $out
    Center-TokenRim -Bitmap $out
    $out.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $out.Dispose()
}

function New-TokenBitmap {
    param([int] $Size)

    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bitmap.SetResolution(96, 96)
    return $bitmap
}

function New-TokenGraphics {
    param([System.Drawing.Bitmap] $Bitmap)

    $graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    return $graphics
}

function Test-AtlasBackgroundPixel {
    param([System.Drawing.Color] $Color)

    if ($Color.A -lt 8) {
        return $true
    }
    $luma = [int](0.299 * $Color.R + 0.587 * $Color.G + 0.114 * $Color.B)
    $max = [Math]::Max($Color.R, [Math]::Max($Color.G, $Color.B))
    $min = [Math]::Min($Color.R, [Math]::Min($Color.G, $Color.B))
    $chroma = $max - $min
    return $luma -lt 45 -and $chroma -lt 24
}

function Remove-AtlasBackground {
    param([System.Drawing.Bitmap] $Bitmap)

    $w = $Bitmap.Width
    $h = $Bitmap.Height
    $count = $w * $h
    $background = [bool[]]::new($count)
    $visited = [bool[]]::new($count)
    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            $index = $y * $w + $x
            $background[$index] = Test-AtlasBackgroundPixel $Bitmap.GetPixel($x, $y)
        }
    }

    $queue = [System.Collections.Generic.Queue[int]]::new()
    for ($x = 0; $x -lt $w; $x++) {
        foreach ($index in @($x, (($h - 1) * $w + $x))) {
            if ($background[$index] -and -not $visited[$index]) {
                $visited[$index] = $true
                $queue.Enqueue($index)
            }
        }
    }
    for ($y = 0; $y -lt $h; $y++) {
        foreach ($index in @(($y * $w), ($y * $w + $w - 1))) {
            if ($background[$index] -and -not $visited[$index]) {
                $visited[$index] = $true
                $queue.Enqueue($index)
            }
        }
    }
    while ($queue.Count -gt 0) {
        $index = $queue.Dequeue()
        $x = $index % $w
        $y = [Math]::Floor($index / $w)
        foreach ($next in @(
            $(if ($x -gt 0) { $index - 1 } else { -1 }),
            $(if ($x -lt $w - 1) { $index + 1 } else { -1 }),
            $(if ($y -gt 0) { $index - $w } else { -1 }),
            $(if ($y -lt $h - 1) { $index + $w } else { -1 })
        )) {
            if ($next -ge 0 -and $background[$next] -and -not $visited[$next]) {
                $visited[$next] = $true
                $queue.Enqueue($next)
            }
        }
    }

    $component = [int[]]::new($count)
    $componentSizes = @{}
    $componentId = 0
    for ($i = 0; $i -lt $count; $i++) {
        if ($visited[$i] -or $component[$i] -ne 0) {
            continue
        }
        $componentId++
        $size = 0
        $queue.Enqueue($i)
        $component[$i] = $componentId
        while ($queue.Count -gt 0) {
            $index = $queue.Dequeue()
            $size++
            $x = $index % $w
            $y = [Math]::Floor($index / $w)
            foreach ($next in @(
                $(if ($x -gt 0) { $index - 1 } else { -1 }),
                $(if ($x -lt $w - 1) { $index + 1 } else { -1 }),
                $(if ($y -gt 0) { $index - $w } else { -1 }),
                $(if ($y -lt $h - 1) { $index + $w } else { -1 })
            )) {
                if ($next -ge 0 -and -not $visited[$next] -and $component[$next] -eq 0) {
                    $component[$next] = $componentId
                    $queue.Enqueue($next)
                }
            }
        }
        $componentSizes[$componentId] = $size
    }

    $keepComponent = 0
    $keepSize = 0
    foreach ($key in $componentSizes.Keys) {
        if ($componentSizes[$key] -gt $keepSize) {
            $keepSize = $componentSizes[$key]
            $keepComponent = [int]$key
        }
    }

    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            $index = $y * $w + $x
            if ($visited[$index] -or $component[$index] -ne $keepComponent) {
                $color = $Bitmap.GetPixel($x, $y)
                $Bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, $color.R, $color.G, $color.B))
            }
        }
    }
}

function Measure-TokenContent {
    param([System.Drawing.Bitmap] $Bitmap)

    $w = $Bitmap.Width
    $h = $Bitmap.Height
    $minX = $w
    $minY = $h
    $maxX = -1
    $maxY = -1
    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            if ($Bitmap.GetPixel($x, $y).A -gt 20) {
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
    return [PSCustomObject]@{
        X = $minX
        Y = $minY
        Right = $maxX
        Bottom = $maxY
        Width = $maxX - $minX + 1
        Height = $maxY - $minY + 1
    }
}

function Test-GoldRimPixel {
    param([System.Drawing.Color] $Color)

    if ($Color.A -lt 20) {
        return $false
    }
    return $Color.R -gt 85 -and $Color.G -gt 55 -and $Color.R -gt ($Color.B + 25) -and $Color.G -gt ($Color.B + 10)
}

function Center-TokenRim {
    param([System.Drawing.Bitmap] $Bitmap)

    $w = $Bitmap.Width
    $h = $Bitmap.Height
    $minX = $w
    $minY = $h
    $maxX = -1
    $maxY = -1
    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            if (Test-GoldRimPixel $Bitmap.GetPixel($x, $y)) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    if ($maxX -lt $minX -or $maxY -lt $minY) {
        return
    }

    $rimCenterX = ($minX + $maxX) / 2.0
    $rimCenterY = ($minY + $maxY) / 2.0
    $targetCenterX = ($w - 1) / 2.0
    $targetCenterY = ($h - 1) / 2.0
    $dx = [int][Math]::Round($targetCenterX - $rimCenterX)
    $dy = [int][Math]::Round($targetCenterY - $rimCenterY)
    if ($dx -eq 0 -and $dy -eq 0) {
        return
    }

    $copy = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($copy)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $graphics.DrawImageUnscaled($Bitmap, $dx, $dy)
    $graphics.Dispose()

    $replace = [System.Drawing.Graphics]::FromImage($Bitmap)
    $replace.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $replace.DrawImageUnscaled($copy, 0, 0)
    $replace.Dispose()
    $copy.Dispose()
}

function Center-TokenContent {
    param([System.Drawing.Bitmap] $Bitmap)

    $w = $Bitmap.Width
    $h = $Bitmap.Height
    $minX = $w
    $minY = $h
    $maxX = -1
    $maxY = -1
    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            if ($Bitmap.GetPixel($x, $y).A -gt 20) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    if ($maxX -lt $minX -or $maxY -lt $minY) {
        return
    }

    $contentCenterX = ($minX + $maxX) / 2.0
    $contentCenterY = ($minY + $maxY) / 2.0
    $targetCenterX = ($w - 1) / 2.0
    $targetCenterY = ($h - 1) / 2.0
    $dx = [int][Math]::Round($targetCenterX - $contentCenterX)
    $dy = [int][Math]::Round($targetCenterY - $contentCenterY)
    if ($dx -eq 0 -and $dy -eq 0) {
        return
    }

    $copy = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($copy)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $graphics.DrawImageUnscaled($Bitmap, $dx, $dy)
    $graphics.Dispose()

    $replace = [System.Drawing.Graphics]::FromImage($Bitmap)
    $replace.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $replace.DrawImageUnscaled($copy, 0, 0)
    $replace.Dispose()
    $copy.Dispose()
}

$atlas = [System.Drawing.Bitmap]::new($atlasPath)
try {
    $xStep = $atlas.Width / 6.0
    $xCenters = for ($i = 0; $i -lt 6; $i++) { ($i + 0.5) * $xStep }

    $yBands = Get-BrightBands -Bitmap $atlas -Axis "y"
    if ($yBands.Count -ne 4) {
        throw "Expected 4 token rows, found $($yBands.Count)."
    }
    $yCenters = foreach ($band in $yBands) { ($band[0] + $band[1]) / 2.0 }
    # Take a larger source region than the atlas cell spacing so rim/shadow detail
    # is not shaved off. Neighboring coins are removed after export by keeping only
    # the main connected coin component.
    $side = 230.0

    Write-Output "atlas: $($atlas.Width)x$($atlas.Height)"
    Write-Output "x centers: $([string]::Join(', ', ($xCenters | ForEach-Object { [Math]::Round($_, 1) })))"
    Write-Output "y centers: $([string]::Join(', ', ($yCenters | ForEach-Object { [Math]::Round($_, 1) })))"
    Write-Output "crop side: $side"

    for ($row = 0; $row -lt 4; $row++) {
        for ($col = 0; $col -lt 6; $col++) {
            $index = $row * 6 + $col
            $name = $names[$index]
            $crop = [System.Drawing.RectangleF]::new(
                [float]($xCenters[$col] - $side / 2.0),
                [float]($yCenters[$row] - $side / 2.0),
                [float]$side,
                [float]$side
            )
            Export-Token -Source $atlas -Crop $crop -Path (Join-Path $tokenDir "$name.png") -Size 256
            Export-Token -Source $atlas -Crop $crop -Path (Join-Path $smallDir "$name.png") -Size 64
        }
    }
}
finally {
    $atlas.Dispose()
}
