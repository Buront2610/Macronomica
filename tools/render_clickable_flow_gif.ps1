param(
    [string]$Name = "macronomica_clickable_flow"
)

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
    throw "Godot executable was not found."
}

$safeName = $Name -replace '[^a-zA-Z0-9_-]', '_'
$outRoot = Join-Path $repo "tmp\screenshots"
$frameDir = Join-Path $outRoot "$safeName`_frames"
$gifPath = Join-Path $outRoot "$safeName.gif"
if (Test-Path $frameDir) {
    Remove-Item $frameDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $frameDir | Out-Null
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

$env:MACRONOMICA_GIF_FRAME_DIR = $frameDir
& $godotPath --path $repo --script "res://tools/render_clickable_flow_frames.gd"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Remove-Item Env:\MACRONOMICA_GIF_FRAME_DIR -ErrorAction SilentlyContinue

$python = @'
from pathlib import Path
from PIL import Image, ImageDraw
import sys

frame_dir = Path(sys.argv[1])
gif_path = Path(sys.argv[2])
frames = []
durations = []
for path in sorted(frame_dir.glob("*.png")):
    img = Image.open(path).convert("RGBA")
    frames.append(img)
    durations.append(850)
if not frames:
    raise SystemExit("no frames rendered")
frames[0].save(
    gif_path,
    save_all=True,
    append_images=frames[1:],
    duration=durations,
    loop=0,
    optimize=True,
)
print(gif_path)
'@
$python | python - $frameDir $gifPath

[pscustomobject]@{
    Gif = $gifPath
    Frames = (Get-ChildItem $frameDir -Filter *.png).Count
}
