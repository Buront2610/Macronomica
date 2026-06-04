$ErrorActionPreference = "Stop"

$repo = Resolve-Path (Join-Path $PSScriptRoot "..")
$godot = Get-Command godot -ErrorAction SilentlyContinue

if ($godot) {
    & $godot.Source --path $repo
    exit $LASTEXITCODE
}

$wingetGodot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64.exe"
if (Test-Path $wingetGodot) {
    & $wingetGodot --path $repo
    exit $LASTEXITCODE
}

Write-Error "Godot executable was not found. Install Godot 4.6.x or restart PowerShell so the winget alias is visible."

