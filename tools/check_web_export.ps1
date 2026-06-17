$ErrorActionPreference = "Stop"

$repo = Resolve-Path (Join-Path $PSScriptRoot "..")
$godot = Get-Command godot_console -ErrorAction SilentlyContinue
if (-not $godot) {
    $godot = Get-Command godot -ErrorAction SilentlyContinue
}
if ($godot) {
    $godotPath = $godot.Source
} else {
    $godotPath = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe"
}
if (-not (Test-Path $godotPath)) {
    throw "Godot console executable was not found."
}

$presetPath = Join-Path $repo "export_presets.cfg"
if (-not (Test-Path $presetPath)) {
    throw "export_presets.cfg is missing."
}

$outDir = Join-Path $repo "exports\web"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
Get-ChildItem $outDir -Force | Where-Object { $_.Name -ne ".gitkeep" } | Remove-Item -Recurse -Force

& $godotPath --headless --path $repo --export-release Web "exports/web/index.html"
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$required = @(
    "index.html",
    "index.js",
    "index.pck",
    "index.wasm"
)
foreach ($name in $required) {
    $path = Join-Path $outDir $name
    if (-not (Test-Path $path)) {
        throw "Web export missing required file: $name"
    }
    if ((Get-Item $path).Length -le 0) {
        throw "Web export produced empty file: $name"
    }
}

$html = Get-Content (Join-Path $outDir "index.html") -Raw
if ($html -notmatch "<title>マクロノミカ</title>") {
    throw "Web export index.html does not include the Japanese application title."
}
if ($html -notmatch "index") {
    throw "Web export index.html does not reference generated runtime assets."
}

Write-Host "Web export check passed."
