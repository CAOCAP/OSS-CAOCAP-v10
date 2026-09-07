# Requires Windows. Launches the unpackaged CAOCAP Hello World exe, waits for the
# CAOCAP window, and writes PNG captures (WGC window, GDI window, desktop).
param(
    [Parameter(Mandatory = $true)]
    [string]$ExePath,
    [Parameter(Mandatory = $true)]
    [string]$OutputDir,
    [string]$WgcCaptureExe = "",
    [int]$TimeoutSeconds = 60
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class CaocapNative {
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, uint nFlags);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

    public static IntPtr FindVisibleWindow(uint pid, string title) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((hWnd, l) => {
            if (!IsWindowVisible(hWnd)) return true;
            GetWindowThreadProcessId(hWnd, out uint windowPid);
            if (pid != 0 && windowPid != pid) return true;
            var sb = new StringBuilder(512);
            GetWindowText(hWnd, sb, sb.Capacity);
            string text = sb.ToString();
            if (string.Equals(text, title, StringComparison.OrdinalIgnoreCase) ||
                text.IndexOf(title, StringComparison.OrdinalIgnoreCase) >= 0) {
                found = hWnd;
                return false;
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    public static string DumpVisibleWindows() {
        var sbAll = new StringBuilder();
        EnumWindows((hWnd, l) => {
            if (!IsWindowVisible(hWnd)) return true;
            GetWindowThreadProcessId(hWnd, out uint windowPid);
            var sb = new StringBuilder(512);
            GetWindowText(hWnd, sb, sb.Capacity);
            sbAll.AppendLine(windowPid + " " + hWnd.ToInt64() + " " + sb);
            return true;
        }, IntPtr.Zero);
        return sbAll.ToString();
    }
}
"@

try { [CaocapNative]::SetProcessDPIAware() } catch { }

function Get-PngStats([string]$Path) {
    $bmp = New-Object System.Drawing.Bitmap $Path
    try {
        $width = $bmp.Width
        $height = $bmp.Height
        if ($width -lt 2 -or $height -lt 2) {
            return [pscustomobject]@{ Width = $width; Height = $height; Unique = 0; White = 1; Black = 1; Mean = 0 }
        }
        $unique = New-Object 'System.Collections.Generic.HashSet[int]'
        $white = 0
        $black = 0
        $sum = 0.0
        $samples = 0
        $stepY = [Math]::Max(1, [int]($height / 48))
        $stepX = [Math]::Max(1, [int]($width / 48))
        for ($y = 0; $y -lt $height; $y += $stepY) {
            for ($x = 0; $x -lt $width; $x += $stepX) {
                $c = $bmp.GetPixel($x, $y)
                [void]$unique.Add($c.ToArgb())
                $luma = (0.2126 * $c.R) + (0.7152 * $c.G) + (0.0722 * $c.B)
                $sum += $luma
                $samples++
                if ($c.R -gt 245 -and $c.G -gt 245 -and $c.B -gt 245) { $white++ }
                if ($c.R -lt 10 -and $c.G -lt 10 -and $c.B -lt 10) { $black++ }
            }
        }
        return [pscustomobject]@{
            Width  = $width
            Height = $height
            Unique = $unique.Count
            White  = if ($samples -eq 0) { 1 } else { $white / $samples }
            Black  = if ($samples -eq 0) { 1 } else { $black / $samples }
            Mean   = if ($samples -eq 0) { 0 } else { $sum / $samples }
        }
    }
    finally {
        $bmp.Dispose()
    }
}

function Test-UsefulCapture([string]$Path) {
    if (-not (Test-Path $Path)) { return $false }
    $info = Get-Item $Path
    if ($info.Length -lt 800) { return $false }
    $stats = Get-PngStats $Path
    if ($stats.Width -lt 80 -or $stats.Height -lt 80) { return $false }
    # Hello World is mostly empty chrome; only reject a true single-color frame.
    if ($stats.Unique -lt 3) { return $false }
    if ($stats.White -gt 0.995 -or $stats.Black -gt 0.995) { return $false }
    return $true
}

function Save-GdiDesktop([string]$Path) {
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
        $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $g.Dispose()
        $bmp.Dispose()
    }
}

function Save-GdiWindow([IntPtr]$Hwnd, [string]$CopyPath, [string]$PrintPath) {
    $rect = New-Object CaocapNative+RECT
    if (-not [CaocapNative]::GetWindowRect($Hwnd, [ref]$rect)) {
        throw "GetWindowRect failed"
    }
    $width = [Math]::Max(1, $rect.Right - $rect.Left)
    $height = [Math]::Max(1, $rect.Bottom - $rect.Top)

    $copy = New-Object System.Drawing.Bitmap $width, $height
    $copyG = [System.Drawing.Graphics]::FromImage($copy)
    try {
        $copyG.CopyFromScreen($rect.Left, $rect.Top, 0, 0, (New-Object System.Drawing.Size $width, $height))
        $copy.Save($CopyPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $copyG.Dispose()
        $copy.Dispose()
    }

    $print = New-Object System.Drawing.Bitmap $width, $height
    $printG = [System.Drawing.Graphics]::FromImage($print)
    $hdc = $printG.GetHdc()
    try {
        # PW_RENDERFULLCONTENT = 2
        [void][CaocapNative]::PrintWindow($Hwnd, $hdc, 2)
        $printG.ReleaseHdc($hdc)
        $print.Save($PrintPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $printG.Dispose()
        $print.Dispose()
    }
}

$exe = (Resolve-Path $ExePath).Path
if (-not (Test-Path $exe)) {
    throw "Executable not found: $ExePath"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$outputDir = (Resolve-Path $OutputDir).Path
$exeDir = Split-Path -Parent $exe
$diagPath = Join-Path $outputDir "capture-diagnostics.txt"

$log = New-Object System.Collections.Generic.List[string]
function Write-Log([string]$Message) {
    $line = "$(Get-Date -Format o) $Message"
    $log.Add($line)
    Write-Host $line
}

Write-Log "exe=$exe"
Write-Log "cwd=$exeDir"
Write-Log "output=$outputDir"
Write-Log "session=$(query session 2>$null | Out-String)"
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
Write-Log "screen=$($screen.Width)x$($screen.Height) at $($screen.X),$($screen.Y)"

$proc = Start-Process -FilePath $exe -WorkingDirectory $exeDir -PassThru
Write-Log "started pid=$($proc.Id)"

$hwnd = [IntPtr]::Zero
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while ((Get-Date) -lt $deadline) {
    if ($proc.HasExited) {
        Write-Log "process exited early code=$($proc.ExitCode)"
        break
    }
    $candidate = [CaocapNative]::FindVisibleWindow([uint32]$proc.Id, "CAOCAP")
    if ($candidate -eq [IntPtr]::Zero) {
        $proc.Refresh()
        if ($proc.MainWindowHandle -ne [IntPtr]::Zero) {
            $candidate = $proc.MainWindowHandle
        }
    }
    if ($candidate -ne [IntPtr]::Zero) {
        $hwnd = $candidate
        break
    }
    Start-Sleep -Milliseconds 400
}

if ($hwnd -eq [IntPtr]::Zero) {
    Write-Log "CAOCAP window not found; listing visible windows"
    Write-Log ([CaocapNative]::DumpVisibleWindows())
}

$useful = @()
$primary = Join-Path $outputDir "caocap-hello-world.png"

if ($hwnd -ne [IntPtr]::Zero) {
    Write-Log "hwnd=$($hwnd.ToInt64())"
    [void][CaocapNative]::ShowWindow($hwnd, 9) # SW_RESTORE
    [void][CaocapNative]::SetForegroundWindow($hwnd)
    Start-Sleep -Seconds 2

    $gdiCopy = Join-Path $outputDir "caocap-window-gdi.png"
    $gdiPrint = Join-Path $outputDir "caocap-window-printwindow.png"
    try {
        Save-GdiWindow -Hwnd $hwnd -CopyPath $gdiCopy -PrintPath $gdiPrint
        Write-Log "wrote GDI captures"
    }
    catch {
        Write-Log "GDI window capture failed: $_"
    }

    if ($WgcCaptureExe -and (Test-Path $WgcCaptureExe)) {
        $wgcWindow = Join-Path $outputDir "caocap-window-wgc.png"
        Write-Log "running WGC window capture"
        & $WgcCaptureExe "$($hwnd.ToInt64())" $wgcWindow
        Write-Log "wgc-capture window exit=$LASTEXITCODE"
    }
}

$desktopGdi = Join-Path $outputDir "caocap-desktop-gdi.png"
try {
    Save-GdiDesktop $desktopGdi
    Write-Log "wrote desktop GDI capture"
}
catch {
    Write-Log "desktop GDI capture failed: $_"
}

if ($WgcCaptureExe -and (Test-Path $WgcCaptureExe)) {
    $wgcDesktop = Join-Path $outputDir "caocap-desktop-wgc.png"
    Write-Log "running WGC monitor capture"
    & $WgcCaptureExe "0" $wgcDesktop
    Write-Log "wgc-capture desktop exit=$LASTEXITCODE"
}

$nircmd = Get-Command nircmd.exe -ErrorAction SilentlyContinue
if ($nircmd) {
    $nircmdPath = Join-Path $outputDir "caocap-desktop-nircmd.png"
    & nircmd.exe savescreenshot $nircmdPath
    Write-Log "nircmd exit=$LASTEXITCODE"
}

$magick = Get-Command magick.exe -ErrorAction SilentlyContinue
if ($magick) {
    $magickPath = Join-Path $outputDir "caocap-desktop-magick.png"
    & magick.exe screenshot $magickPath
    Write-Log "magick exit=$LASTEXITCODE"
}

$preference = @(
    (Join-Path $outputDir "caocap-window-wgc.png"),
    (Join-Path $outputDir "caocap-window-gdi.png"),
    (Join-Path $outputDir "caocap-window-printwindow.png"),
    (Join-Path $outputDir "caocap-desktop-wgc.png"),
    (Join-Path $outputDir "caocap-desktop-gdi.png"),
    (Join-Path $outputDir "caocap-desktop-nircmd.png"),
    (Join-Path $outputDir "caocap-desktop-magick.png")
)

$chosen = $null
$chosenKind = $null
foreach ($path in $preference) {
    if (Test-UsefulCapture $path) {
        $chosen = $path
        $chosenKind = Split-Path -Leaf $path
        break
    }
    elseif (Test-Path $path) {
        $stats = Get-PngStats $path
        Write-Log "rejected $path size=$($stats.Width)x$($stats.Height) unique=$($stats.Unique) white=$([math]::Round($stats.White,3)) black=$([math]::Round($stats.Black,3))"
    }
}

if ($chosen) {
    Copy-Item -Force $chosen $primary
    Write-Log "primary=$chosenKind -> $primary"
    $useful += $chosenKind
}

if (-not $proc.HasExited) {
    try { $proc.CloseMainWindow() | Out-Null } catch { }
    Start-Sleep -Milliseconds 500
    if (-not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
}

$log | Set-Content -Path $diagPath -Encoding utf8
Write-Log "diagnostics=$diagPath"

if (-not $chosen) {
    throw "No useful screenshot of the CAOCAP Hello World window was captured."
}

if ($hwnd -eq [IntPtr]::Zero) {
    Write-Warning "Primary screenshot is not a dedicated window capture; the CAOCAP HWND was never found."
}

Write-Host "Captured $chosenKind"
exit 0
