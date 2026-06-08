$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$repo = Resolve-Path (Join-Path $PSScriptRoot "..")
$atlasPath = Join-Path $repo "assets\ui\tokens\macronomica_token_atlas.png"
$tokenDir = Join-Path $repo "assets\ui\tokens"
$outDir = Join-Path $repo "docs\assets\uiux\qa"

$names = @(
    "fiscal_treasury", "central_bank", "trade_port", "industry_factory", "financial_shield", "diplomacy_handshake",
    "reform_wrench", "social_safety_net", "debt_chain", "currency_arrows", "unemployment_people", "inflation_flame",
    "world_demand_globe", "interest_rate_coin", "trade_gate", "financial_storm", "depression_shadow", "protection_wall",
    "coordination_ring", "bureaucrat_seal", "central_bank_staff_seal", "diplomat_seal", "auditor_seal", "lobbyist_seal"
)

function New-Graphics {
    param([System.Drawing.Bitmap] $Bitmap)

    $graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    return $graphics
}

function Render-ContactSheet {
    param([string[]] $TokenNames)

    $sheet = [System.Drawing.Bitmap]::new(768, 576, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = New-Graphics $sheet
    $graphics.Clear([System.Drawing.Color]::FromArgb(18, 18, 15))
    $font = [System.Drawing.Font]::new("Consolas", 9, [System.Drawing.FontStyle]::Regular)
    $border = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(90, 210, 135), 1)
    try {
        for ($i = 0; $i -lt $TokenNames.Count; $i++) {
            $col = $i % 6
            $row = [Math]::Floor($i / 6)
            $x = $col * 128
            $y = $row * 144
            $graphics.DrawRectangle($border, $x + 1, $y + 1, 126, 126)
            $image = [System.Drawing.Bitmap]::new((Join-Path $tokenDir "$($TokenNames[$i]).png"))
            try {
                $graphics.DrawImage($image, [System.Drawing.RectangleF]::new($x + 12, $y + 6, 104, 104))
            }
            finally {
                $image.Dispose()
            }
            $graphics.DrawString($TokenNames[$i], $font, [System.Drawing.Brushes]::White, $x + 4, $y + 126)
        }
        $sheet.Save((Join-Path $outDir "token-contact-sheet.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $border.Dispose()
        $font.Dispose()
        $graphics.Dispose()
        $sheet.Dispose()
    }
}

function Render-SourceComparison {
    param([System.Drawing.Bitmap] $Atlas, [string[]] $TokenNames)

    $side = 230.0
    $xStep = $Atlas.Width / 6.0
    $xCenters = for ($i = 0; $i -lt 6; $i++) { ($i + 0.5) * $xStep }
    $yCenters = @(206.0, 464.0, 726.0, 992.0)
    $sheet = [System.Drawing.Bitmap]::new(720, 2400, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = New-Graphics $sheet
    $graphics.Clear([System.Drawing.Color]::FromArgb(18, 18, 15))
    $font = [System.Drawing.Font]::new("Consolas", 9, [System.Drawing.FontStyle]::Regular)
    $small = [System.Drawing.Font]::new("Consolas", 8, [System.Drawing.FontStyle]::Regular)
    $red = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(230, 70, 80), 1)
    $blue = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(80, 170, 255), 1)
    $gold = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(240, 210, 120), 1)
    try {
        for ($i = 0; $i -lt $TokenNames.Count; $i++) {
            $pair = $i % 2
            $row = [Math]::Floor($i / 2)
            $baseX = 8 + $pair * 360
            $baseY = 8 + $row * 184
            $name = $TokenNames[$i]
            $src = [System.Drawing.RectangleF]::new(
                [float]($xCenters[$i % 6] - $side / 2.0),
                [float]($yCenters[[Math]::Floor($i / 6)] - $side / 2.0),
                [float]$side,
                [float]$side
            )
            $graphics.DrawString($name, $font, [System.Drawing.Brushes]::White, $baseX, $baseY)
            $graphics.DrawString("source crop 230", $small, [System.Drawing.Brushes]::Wheat, $baseX + 22, $baseY + 14)
            $graphics.DrawImage($Atlas, [System.Drawing.RectangleF]::new($baseX, $baseY + 30, 118, 118), $src, [System.Drawing.GraphicsUnit]::Pixel)
            $graphics.DrawRectangle($blue, $baseX, $baseY + 30, 118, 118)
            $graphics.DrawLine($red, $baseX + 59, $baseY + 30, $baseX + 59, $baseY + 148)
            $graphics.DrawLine($red, $baseX, $baseY + 89, $baseX + 118, $baseY + 89)

            $image = [System.Drawing.Bitmap]::new((Join-Path $tokenDir "$name.png"))
            try {
                $graphics.DrawString("final png / center", $small, [System.Drawing.Brushes]::Wheat, $baseX + 168, $baseY + 14)
                $graphics.DrawImage($image, [System.Drawing.RectangleF]::new($baseX + 158, $baseY + 30, 118, 118))
            }
            finally {
                $image.Dispose()
            }
            $graphics.DrawEllipse($gold, $baseX + 158, $baseY + 30, 118, 118)
            $graphics.DrawLine($red, $baseX + 217, $baseY + 30, $baseX + 217, $baseY + 148)
            $graphics.DrawLine($red, $baseX + 158, $baseY + 89, $baseX + 276, $baseY + 89)
        }
        $sheet.Save((Join-Path $outDir "token-source-output-check.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $gold.Dispose()
        $blue.Dispose()
        $red.Dispose()
        $small.Dispose()
        $font.Dispose()
        $graphics.Dispose()
        $sheet.Dispose()
    }
}

function Render-SourceCropSheet {
    param([System.Drawing.Bitmap] $Atlas)

    $side = 230.0
    $xStep = $Atlas.Width / 6.0
    $xCenters = for ($i = 0; $i -lt 6; $i++) { ($i + 0.5) * $xStep }
    $yCenters = @(206.0, 464.0, 726.0, 992.0)
    $sheet = [System.Drawing.Bitmap]::new($Atlas.Width, $Atlas.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = New-Graphics $sheet
    $graphics.DrawImage($Atlas, 0, 0, $Atlas.Width, $Atlas.Height)
    $cropPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 80, 190, 255), 3)
    $centerPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(220, 255, 80, 80), 2)
    try {
        for ($row = 0; $row -lt 4; $row++) {
            for ($col = 0; $col -lt 6; $col++) {
                $x = $xCenters[$col] - $side / 2.0
                $y = $yCenters[$row] - $side / 2.0
                $graphics.DrawRectangle($cropPen, [single]$x, [single]$y, [single]$side, [single]$side)
                $graphics.DrawLine($centerPen, [single]$xCenters[$col], [single]($y + 10), [single]$xCenters[$col], [single]($y + $side - 10))
                $graphics.DrawLine($centerPen, [single]($x + 10), [single]$yCenters[$row], [single]($x + $side - 10), [single]$yCenters[$row])
            }
        }
        $sheet.Save((Join-Path $outDir "token-crop-source.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $centerPen.Dispose()
        $cropPen.Dispose()
        $graphics.Dispose()
        $sheet.Dispose()
    }
}

$atlas = [System.Drawing.Bitmap]::new($atlasPath)
try {
    Render-ContactSheet -TokenNames $names
    Render-SourceComparison -Atlas $atlas -TokenNames $names
    Render-SourceCropSheet -Atlas $atlas
}
finally {
    $atlas.Dispose()
}
