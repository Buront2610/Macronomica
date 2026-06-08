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

    $out = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $out.SetResolution(96, 96)
    $graphics = [System.Drawing.Graphics]::FromImage($out)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $clip = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $inset = [Math]::Max(1.0, $Size * 0.018)
    $clip.AddEllipse($inset, $inset, $Size - $inset * 2.0, $Size - $inset * 2.0)
    $graphics.SetClip($clip)
    $graphics.DrawImage($Source, [System.Drawing.RectangleF]::new(0, 0, $Size, $Size), $Crop, [System.Drawing.GraphicsUnit]::Pixel)
    $graphics.ResetClip()

    $graphics.Dispose()
    $clip.Dispose()
    $out.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $out.Dispose()
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
    # Keep a small gutter inside each atlas cell. The generated coins nearly touch the
    # neighboring cells, so a full-cell crop pulls stray rim fragments into the token.
    $side = 196.0

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
