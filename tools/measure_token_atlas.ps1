param(
    [string] $OutputPath = "docs\assets\uiux\qa\token-atlas-detected-centers.png"
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$repo = Resolve-Path (Join-Path $PSScriptRoot "..")
$atlasPath = Join-Path $repo "assets\ui\tokens\macronomica_token_atlas.png"

$names = @(
    "fiscal_treasury", "central_bank", "trade_port", "industry_factory", "financial_shield", "diplomacy_handshake",
    "reform_wrench", "social_safety_net", "debt_chain", "currency_arrows", "unemployment_people", "inflation_flame",
    "world_demand_globe", "interest_rate_coin", "trade_gate", "financial_storm", "depression_shadow", "protection_wall",
    "coordination_ring", "bureaucrat_seal", "central_bank_staff_seal", "diplomat_seal", "auditor_seal", "lobbyist_seal"
)

function Test-GoldRimPixel {
    param([System.Drawing.Color] $Color)

    if ($Color.A -lt 20) {
        return $false
    }
    $max = [Math]::Max($Color.R, [Math]::Max($Color.G, $Color.B))
    $min = [Math]::Min($Color.R, [Math]::Min($Color.G, $Color.B))
    $chroma = $max - $min
    return $Color.R -gt 92 -and $Color.G -gt 58 -and $Color.R -gt ($Color.B + 26) -and $Color.G -gt ($Color.B + 8) -and $chroma -gt 32
}

function Measure-RimInRect {
    param(
        [System.Drawing.Bitmap] $Bitmap,
        [System.Drawing.Rectangle] $Rect
    )

    $minX = $Bitmap.Width
    $minY = $Bitmap.Height
    $maxX = -1
    $maxY = -1
    $count = 0
    for ($y = $Rect.Top; $y -lt $Rect.Bottom; $y++) {
        for ($x = $Rect.Left; $x -lt $Rect.Right; $x++) {
            if (Test-GoldRimPixel $Bitmap.GetPixel($x, $y)) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
                $count++
            }
        }
    }
    if ($maxX -lt $minX -or $maxY -lt $minY) {
        return $null
    }
    return [pscustomobject]@{
        X = $minX
        Y = $minY
        Right = $maxX
        Bottom = $maxY
        CenterX = ($minX + $maxX) / 2.0
        CenterY = ($minY + $maxY) / 2.0
        Width = $maxX - $minX + 1
        Height = $maxY - $minY + 1
        Count = $count
    }
}

$atlas = [System.Drawing.Bitmap]::new($atlasPath)
try {
    $xStep = $atlas.Width / 6.0
    $yCenters = @(206.0, 464.0, 726.0, 992.0)
    $cellSide = 190
    $measurements = @()

    $overlay = [System.Drawing.Bitmap]::new($atlas)
    $graphics = [System.Drawing.Graphics]::FromImage($overlay)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $gridPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(180, 255, 80, 80), 2)
    $rimPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 80, 220, 255), 3)
    $font = [System.Drawing.Font]::new("Consolas", 14)
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 255, 245, 180))
    try {
        for ($row = 0; $row -lt 4; $row++) {
            for ($col = 0; $col -lt 6; $col++) {
                $index = $row * 6 + $col
                $gridX = ($col + 0.5) * $xStep
                $gridY = $yCenters[$row]
                $rect = [System.Drawing.Rectangle]::new(
                    [int][Math]::Round($gridX - $cellSide / 2.0),
                    [int][Math]::Round($gridY - $cellSide / 2.0),
                    $cellSide,
                    $cellSide
                )
                $rim = Measure-RimInRect -Bitmap $atlas -Rect $rect
                if ($rim -eq $null) {
                    throw "No rim detected for $($names[$index])"
                }
                $dx = $rim.CenterX - $gridX
                $dy = $rim.CenterY - $gridY
                $measurements += [pscustomobject]@{
                    Name = $names[$index]
                    GridX = [Math]::Round($gridX, 1)
                    GridY = [Math]::Round($gridY, 1)
                    RimX = [Math]::Round($rim.CenterX, 1)
                    RimY = [Math]::Round($rim.CenterY, 1)
                    DeltaX = [Math]::Round($dx, 1)
                    DeltaY = [Math]::Round($dy, 1)
                    RimW = $rim.Width
                    RimH = $rim.Height
                }
                $graphics.DrawLine($gridPen, [single]$gridX, [single]($gridY - 92), [single]$gridX, [single]($gridY + 92))
                $graphics.DrawLine($gridPen, [single]($gridX - 92), [single]$gridY, [single]($gridX + 92), [single]$gridY)
                $graphics.DrawRectangle($rimPen, $rim.X, $rim.Y, $rim.Width, $rim.Height)
                $graphics.DrawLine($rimPen, [single]($rim.CenterX - 12), [single]$rim.CenterY, [single]($rim.CenterX + 12), [single]$rim.CenterY)
                $graphics.DrawLine($rimPen, [single]$rim.CenterX, [single]($rim.CenterY - 12), [single]$rim.CenterX, [single]($rim.CenterY + 12))
                $graphics.DrawString("$([Math]::Round($dx, 1)),$([Math]::Round($dy, 1))", $font, $brush, [single]($gridX - 52), [single]($gridY + 74))
            }
        }
        $absoluteOutput = Join-Path $repo $OutputPath
        New-Item -ItemType Directory -Force -Path (Split-Path $absoluteOutput) | Out-Null
        $overlay.Save($absoluteOutput, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $brush.Dispose()
        $font.Dispose()
        $rimPen.Dispose()
        $gridPen.Dispose()
        $graphics.Dispose()
        $overlay.Dispose()
    }

    $measurements | Format-Table -AutoSize
    Write-Output "Overlay: $OutputPath"
}
finally {
    $atlas.Dispose()
}
