param(
    [int]$Width = 0,
    [int]$Height = 0,
    [switch]$Maximize,
    [string]$Name = "godot_window"
)

$ErrorActionPreference = "Stop"

Add-Type @"
using System;
using System.Runtime.InteropServices;
public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
public struct POINT { public int X; public int Y; }
public class WinApi {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr hWnd, ref POINT lpPoint);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$process = Get-Process |
    Where-Object { $_.ProcessName -like 'Godot*' -and $_.MainWindowHandle -ne 0 } |
    Select-Object -First 1

if (-not $process) {
    throw "No Godot window found."
}

[WinApi]::ShowWindow($process.MainWindowHandle, $(if ($Maximize) { 3 } else { 1 })) | Out-Null
Start-Sleep -Milliseconds 500
if (-not $Maximize -and $Width -gt 0 -and $Height -gt 0) {
    [WinApi]::SetWindowPos($process.MainWindowHandle, [IntPtr]::Zero, 40, 40, $Width, $Height, 0x0040) | Out-Null
    Start-Sleep -Milliseconds 800
}
if (-not $Maximize -and $Width -gt 0 -and $Height -gt 0) {
    [WinApi]::SetWindowPos($process.MainWindowHandle, [IntPtr](-1), 40, 40, $Width, $Height, 0x0040) | Out-Null
} else {
    [WinApi]::SetWindowPos($process.MainWindowHandle, [IntPtr](-1), 0, 0, 0, 0, 0x0001 -bor 0x0002 -bor 0x0040) | Out-Null
}
[WinApi]::SetForegroundWindow($process.MainWindowHandle) | Out-Null
Start-Sleep -Seconds 1

$windowRect = New-Object RECT
[WinApi]::GetWindowRect($process.MainWindowHandle, [ref]$windowRect) | Out-Null
$clientRect = New-Object RECT
[WinApi]::GetClientRect($process.MainWindowHandle, [ref]$clientRect) | Out-Null
$clientPoint = New-Object POINT
$clientPoint.X = 0
$clientPoint.Y = 0
[WinApi]::ClientToScreen($process.MainWindowHandle, [ref]$clientPoint) | Out-Null
$width = [Math]::Max(1, $clientRect.Right - $clientRect.Left)
$height = [Math]::Max(1, $clientRect.Bottom - $clientRect.Top)

$outDir = Join-Path (Resolve-Path ".") "tmp\screenshots"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$safeName = $Name -replace '[^a-zA-Z0-9_-]', '_'
$out = Join-Path $outDir "$safeName.png"

$bitmap = New-Object System.Drawing.Bitmap $width, $height
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($clientPoint.X, $clientPoint.Y, 0, 0, (New-Object System.Drawing.Size $width, $height))
$bitmap.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()

$windowWidth = [Math]::Max(1, $windowRect.Right - $windowRect.Left)
$windowHeight = [Math]::Max(1, $windowRect.Bottom - $windowRect.Top)
[WinApi]::SetWindowPos($process.MainWindowHandle, [IntPtr](-2), $windowRect.Left, $windowRect.Top, $windowWidth, $windowHeight, 0x0040) | Out-Null

[pscustomobject]@{
    Path = $out
    Width = $width
    Height = $height
    Left = $clientPoint.X
    Top = $clientPoint.Y
    Title = $process.MainWindowTitle
}
