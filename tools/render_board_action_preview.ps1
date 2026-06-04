$ErrorActionPreference = "Stop"

$repo = Resolve-Path (Join-Path $PSScriptRoot "..")
$godot = Get-Command godot -ErrorAction SilentlyContinue
if ($godot) {
    $godotPath = $godot.Source
} else {
    $godotPath = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64.exe"
}
if (-not (Test-Path $godotPath)) {
    throw "Godot executable was not found."
}

$outDir = Join-Path $repo "tmp\screenshots"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$env:MACRONOMICA_PREVIEW_PATH = Join-Path $outDir "board_action_preview.png"

& $godotPath --path $repo --script "res://tools/render_board_action_preview.gd"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

[pscustomobject]@{
    Path = $env:MACRONOMICA_PREVIEW_PATH
}
