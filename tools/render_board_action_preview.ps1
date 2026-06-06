param(
    [int]$Width = 0,
    [int]$Height = 0,
    [string]$Name = "board_action_preview"
)

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
$safeName = $Name -replace '[^a-zA-Z0-9_-]', '_'
$env:MACRONOMICA_PREVIEW_PATH = Join-Path $outDir "$safeName.png"
if ($Width -gt 0) {
    $env:MACRONOMICA_PREVIEW_WIDTH = "$Width"
} else {
    Remove-Item Env:\MACRONOMICA_PREVIEW_WIDTH -ErrorAction SilentlyContinue
}
if ($Height -gt 0) {
    $env:MACRONOMICA_PREVIEW_HEIGHT = "$Height"
} else {
    Remove-Item Env:\MACRONOMICA_PREVIEW_HEIGHT -ErrorAction SilentlyContinue
}

& $godotPath --path $repo --script "res://tools/render_board_action_preview.gd"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

[pscustomobject]@{
    Path = $env:MACRONOMICA_PREVIEW_PATH
}
