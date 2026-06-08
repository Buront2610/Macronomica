$ErrorActionPreference = "Stop"

$repo = Resolve-Path (Join-Path $PSScriptRoot "..")
$godot = Get-Command godot_console -ErrorAction SilentlyContinue
if (-not $godot) {
    $godot = Get-Command godot -ErrorAction SilentlyContinue
}

if ($godot) {
    & $godot.Source --headless --path $repo --scene "res://scenes/main/main.tscn" --quit-after 3
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $godot.Source --headless --path $repo --script "res://tests/smoke_game_flow.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $godot.Source --headless --path $repo --script "res://tests/smoke_domain_rules.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $godot.Source --headless --path $repo --script "res://tests/smoke_policy_recommender.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $godot.Source --headless --path $repo --script "res://tests/smoke_ui_layout.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $godot.Source --headless --path $repo --script "res://tests/smoke_board_surface_contract.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $godot.Source --headless --path $repo --script "res://tests/smoke_board_runtime_contract.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $godot.Source --headless --path $repo --script "res://tests/smoke_board_interaction.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $godot.Source --headless --path $repo --script "res://tests/e2e_entry_flow.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $godot.Source --headless --path $repo --script "res://tests/e2e_main_board_flow.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $godot.Source --headless --path $repo --script "res://tests/e2e_resolution_outcome.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $godot.Source --headless --path $repo --script "res://tests/e2e_final_score_overlay.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $godot.Source --headless --path $repo --script "res://tests/smoke_ui_components.gd"
    exit $LASTEXITCODE
}

$wingetGodot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe"
if (Test-Path $wingetGodot) {
    & $wingetGodot --headless --path $repo --scene "res://scenes/main/main.tscn" --quit-after 3
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $wingetGodot --headless --path $repo --script "res://tests/smoke_game_flow.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $wingetGodot --headless --path $repo --script "res://tests/smoke_domain_rules.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $wingetGodot --headless --path $repo --script "res://tests/smoke_policy_recommender.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $wingetGodot --headless --path $repo --script "res://tests/smoke_ui_layout.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $wingetGodot --headless --path $repo --script "res://tests/smoke_board_surface_contract.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $wingetGodot --headless --path $repo --script "res://tests/smoke_board_runtime_contract.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $wingetGodot --headless --path $repo --script "res://tests/smoke_board_interaction.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $wingetGodot --headless --path $repo --script "res://tests/e2e_entry_flow.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $wingetGodot --headless --path $repo --script "res://tests/e2e_main_board_flow.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $wingetGodot --headless --path $repo --script "res://tests/e2e_resolution_outcome.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $wingetGodot --headless --path $repo --script "res://tests/e2e_final_score_overlay.gd"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $wingetGodot --headless --path $repo --script "res://tests/smoke_ui_components.gd"
    exit $LASTEXITCODE
}

Write-Error "Godot console executable was not found. Install Godot 4.6.x or restart PowerShell so the winget alias is visible."
