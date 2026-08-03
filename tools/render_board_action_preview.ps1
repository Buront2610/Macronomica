param(
    [int]$Width = 0,
    [int]$Height = 0,
    [string]$State = "",
    [string]$Name = "board_action_preview"
)

$ErrorActionPreference = "Stop"

$repo = Resolve-Path (Join-Path $PSScriptRoot "..")
$wingetConsole = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe"
$wingetGui = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64.exe"
$godot = Get-Command godot -ErrorAction SilentlyContinue
if (Test-Path $wingetGui) {
    $godotPath = $wingetGui
} elseif ($godot) {
    $godotPath = $godot.Source
} elseif (Test-Path $wingetConsole) {
    $godotPath = $wingetConsole
} else {
    $godotPath = ""
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
if (-not [string]::IsNullOrWhiteSpace($State)) {
    $env:MACRONOMICA_PREVIEW_STATE = $State
} else {
    Remove-Item Env:\MACRONOMICA_PREVIEW_STATE -ErrorAction SilentlyContinue
}

$process = Start-Process -FilePath $godotPath -ArgumentList @("--path", "$repo", "--script", "res://tools/render_board_action_preview.gd") -Wait -PassThru -WindowStyle Hidden
if ($process.ExitCode -ne 0) { exit $process.ExitCode }

[pscustomobject]@{
    Path = $env:MACRONOMICA_PREVIEW_PATH
}
