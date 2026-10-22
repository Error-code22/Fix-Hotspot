# Generates hotspot.ico (multi-resolution) and preview images for the project.
# Requires Windows PowerShell 5.1 (System.Drawing).

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$outDir = $PSScriptRoot
$masterSize = 1024

function New-RoundedPath {
    param([float]$X, [float]$Y, [float]$W, [float]$H, [float]$R)
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $R * 2
    $p.AddArc($X, $Y, $d, $d, 180, 90)
    $p.AddArc($X + $W - $d, $Y, $d, $d, 270, 90)
    $p.AddArc($X + $W - $d, $Y + $H - $d, $d, $d, 0, 90)
    $p.AddArc($X, $Y + $H - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

# ---- master artwork -------------------------------------------------------
$bmp = New-Object System.Drawing.Bitmap($masterSize, $masterSize)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.Clear([System.Drawing.Color]::Transparent)

$margin = 48
$tile = $masterSize - (2 * $margin)
$radius = 210

$path = New-RoundedPath -X $margin -Y $margin -W $tile -H $tile -R $radius
$rect = New-Object System.Drawing.Rectangle($margin, $margin, $tile, $tile)
$brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.Color]::FromArgb(255, 56, 189, 248),   # sky
    [System.Drawing.Color]::FromArgb(255, 37, 99, 235),    # blue
    45.0)
$g.FillPath($brush, $path)

# subtle top highlight
$glow = New-Object System.Drawing.Drawing2D.GraphicsPath
$glow.AddEllipse(-260, -420, 1500, 900)
$glowBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle(0, 0, $masterSize, 520)),
    [System.Drawing.Color]::FromArgb(70, 255, 255, 255),
    [System.Drawing.Color]::FromArgb(0, 255, 255, 255),
    90.0)
$g.SetClip($path)
$g.FillPath($glowBrush, $glow)
$g.ResetClip()

# Wi-Fi glyph
$cx = 512
$cy = 690
$penColor = [System.Drawing.Color]::White

foreach ($r in 400, 270, 140) {
    $pen = New-Object System.Drawing.Pen($penColor, 58)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $arcRect = [System.Drawing.Rectangle]::new($cx - $r, $cy - $r, 2 * $r, 2 * $r)
    $g.DrawArc($pen, $arcRect, 205, 130)
    $pen.Dispose()
}

$dot = New-Object System.Drawing.SolidBrush($penColor)
$g.FillEllipse($dot, $cx - 46, $cy - 46, 92, 92)

$g.Dispose()

# ---- outputs --------------------------------------------------------------
$pngPath = Join-Path $outDir 'hotspot.png'
$bmp.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)

$sizes = 16, 24, 32, 48, 64, 128, 256
$entries = @()
foreach ($s in $sizes) {
    $small = New-Object System.Drawing.Bitmap($s, $s)
    $sg = [System.Drawing.Graphics]::FromImage($small)
    $sg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $sg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $sg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $sg.DrawImage($bmp, 0, 0, $s, $s)
    $sg.Dispose()
    $ms = New-Object System.IO.MemoryStream
    $small.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $entries += , @($s, $ms.ToArray())
    $small.Dispose()
    $ms.Dispose()
}

$icoPath = Join-Path $outDir 'hotspot.ico'
$fs = [System.IO.File]::Create($icoPath)
$bw = New-Object System.IO.BinaryWriter($fs)
$bw.Write([UInt16]0)
$bw.Write([UInt16]1)
$bw.Write([UInt16]$entries.Count)
$offset = 6 + (16 * $entries.Count)
foreach ($e in $entries) {
    $s = [int]$e[0]
    $data = [byte[]]$e[1]
    $dim = if ($s -ge 256) { 0 } else { $s }
    $bw.Write([byte]$dim)
    $bw.Write([byte]$dim)
    $bw.Write([byte]0)
    $bw.Write([byte]0)
    $bw.Write([UInt16]1)
    $bw.Write([UInt16]32)
    $bw.Write([UInt32]$data.Length)
    $bw.Write([UInt32]$offset)
    $offset += $data.Length
}
foreach ($e in $entries) { $bw.Write([byte[]]$e[1]) }
$bw.Flush()
$bw.Dispose()
$fs.Dispose()

# ---- contact sheet for QA -------------------------------------------------
$sheet = New-Object System.Drawing.Bitmap(640, 200)
$sgfx = [System.Drawing.Graphics]::FromImage($sheet)
$sgfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$sgfx.Clear([System.Drawing.Color]::FromArgb(255, 243, 244, 246))
$font = New-Object System.Drawing.Font('Segoe UI', 9)
$labelBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 55, 65, 81))
$xs = @(20, 70, 120, 190, 300)
$i = 0
foreach ($s in 16, 32, 48, 64, 128) {
    $img = New-Object System.Drawing.Bitmap($s, $s)
    $ig = [System.Drawing.Graphics]::FromImage($img)
    $ig.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $ig.DrawImage($bmp, 0, 0, $s, $s)
    $ig.Dispose()
    $y = 40 + (128 - $s) / 2
    $sgfx.DrawImage($img, $xs[$i], $y, $s, $s)
    $sgfx.DrawString("$s px", $font, $labelBrush, $xs[$i], 175)
    $img.Dispose()
    $i++
}
$sgfx.Dispose()
$sheet.Save((Join-Path $outDir 'hotspot-contact-sheet.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$sheet.Dispose()
$bmp.Dispose()

Write-Host "Created:"
Write-Host "  $icoPath"
Write-Host "  $pngPath"
Write-Host "  $(Join-Path $outDir 'hotspot-contact-sheet.png')"
