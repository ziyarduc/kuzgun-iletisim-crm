#Requires -Version 5.1
<#
  Kuzgun CRM - prod exe uretimi
  Usage:  powershell -ExecutionPolicy Bypass -File exe\Uret-Exe.ps1 [-TestiAtla]
  Output: C:\ozi\KuzgunCRM_Kurulum.exe  (tek dosya, her seyi icerir)
#>
param([switch]$TestiAtla)

$ErrorActionPreference = 'Stop'

$exeDir = $PSScriptRoot
if (-not $exeDir) { $exeDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$root = Split-Path -Parent $exeDir

$ProgramCs = Join-Path $exeDir 'Program.cs'
$payload = @('Kurulum.ps1', 'Code.gs', 'Kuzgun_Iletisim_CRM.html', 'appsscript.json', 'README.md')
foreach ($f in $payload) {
    if (-not (Test-Path (Join-Path $root $f))) { throw "Eksik kaynak dosya: $f" }
}
if (-not (Test-Path $ProgramCs)) { throw 'Eksik dosya: exe\Program.cs' }

function Satir { param($renk, $metin) Write-Host $metin -ForegroundColor $renk }

# --- ikon uretimi (16/32/48 PNG -> tek .ico) ---
Add-Type -AssemblyName System.Drawing

function New-IkonPng {
    param([int]$s)
    $bmp = New-Object System.Drawing.Bitmap($s, $s)
    try {
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try {
            $g.SmoothingMode = 'AntiAlias'
            $g.TextRenderingHint = 'AntiAliasGridFit'
            $g.Clear([System.Drawing.Color]::Transparent)
            $pad = [float][math]::Max(1, [int]($s * 0.06))
            $w = [float]($s - 2 * $pad)
            $r = [float]($w * 0.24)
            $d = [float]($r * 2)
            $x = $pad; $y = $pad; $right = [float]($pad + $w); $bottom = [float]($pad + $w)
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $path.AddArc([System.Drawing.RectangleF]::new($x, $y, $d, $d), 180, 90)
            $path.AddArc([System.Drawing.RectangleF]::new($right - $d, $y, $d, $d), 270, 90)
            $path.AddArc([System.Drawing.RectangleF]::new($right - $d, $bottom - $d, $d, $d), 0, 90)
            $path.AddArc([System.Drawing.RectangleF]::new($x, $bottom - $d, $d, $d), 90, 90)
            $path.CloseFigure()
            $br = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 30, 58, 95))
            $g.FillPath($br, $path)
            $br.Dispose(); $path.Dispose()
            $fmt = New-Object System.Drawing.StringFormat
            $fmt.Alignment = 'Center'
            $fmt.LineAlignment = 'Center'
            $font = New-Object System.Drawing.Font('Segoe UI', [float]($s * 0.56), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
            $br2 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 240, 244, 248))
            $g.DrawString('K', $font, $br2, [System.Drawing.RectangleF]::new($x, $y, $w, $w), $fmt)
            $font.Dispose(); $br2.Dispose(); $fmt.Dispose()
        } finally { $g.Dispose() }
        $ms = New-Object System.IO.MemoryStream
        try {
            $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
            return , $ms.ToArray()
        } finally { $ms.Dispose() }
    } finally { $bmp.Dispose() }
}

function New-IkonDosya {
    param([string]$yol)
    $boyutlar = 16, 32, 48
    $pngs = @()
    foreach ($b in $boyutlar) { $pngs += , (New-IkonPng $b) }
    $fs = [System.IO.File]::Create($yol)
    try {
        $bw = New-Object System.IO.BinaryWriter($fs)
        $bw.Write([uint16]0)
        $bw.Write([uint16]1)
        $bw.Write([uint16]$boyutlar.Count)
        $toplam = 6 + 16 * $boyutlar.Count
        for ($i = 0; $i -lt $boyutlar.Count; $i++) {
            $s = $boyutlar[$i]
            $bw.Write([byte]$s)
            $bw.Write([byte]$s)
            $bw.Write([byte]0)
            $bw.Write([byte]0)
            $bw.Write([uint16]1)
            $bw.Write([uint16]32)
            $bw.Write([uint32]$pngs[$i].Length)
            $bw.Write([uint32]$toplam)
            $toplam += $pngs[$i].Length
        }
        foreach ($p in $pngs) { $bw.Write($p) }
        $bw.Flush()
    } finally { $fs.Dispose() }
}

$icoYol = Join-Path $exeDir 'kuzgun.ico'
New-IkonDosya $icoYol
Satir Cyan ("[1/3] Ikon uretildi: " + $icoYol)

# --- derleme (csc, .NET Framework - her Windows'ta calisir) ---
$csc = Join-Path $env:windir 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:windir 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path $csc)) { throw 'csc.exe bulunamadi (.NET Framework 4 gerekli)' }

$exeOut = Join-Path $root 'KuzgunCRM_Kurulum.exe'
Push-Location $exeDir
try {
    $cscArgs = @(
        '/nologo', '/target:exe', '/platform:anycpu', '/optimize+',
        '/main:KuzgunCrmSetup.Program',
        '/win32icon:kuzgun.ico',
        '/out:..\KuzgunCRM_Kurulum.exe',
        'Program.cs'
    )
    foreach ($f in $payload) { $cscArgs += "/resource:..\$f,payload.$f" }
    & $csc @cscArgs
    if ($LASTEXITCODE -ne 0) { throw "Derleme hatasi (csc exit=$LASTEXITCODE)" }
} finally { Pop-Location }

if (-not (Test-Path $exeOut)) { throw 'EXE olusmadi' }
$vi = (Get-Item $exeOut).VersionInfo
$kb = [math]::Round((Get-Item $exeOut).Length / 1KB, 1)
Satir Cyan ("[2/3] Derlendi: " + $exeOut + "  (" + $kb + " KB, v" + $vi.FileVersion + ")")

# --- dogrulama: exe'yi asil testten gecir ---
if (-not $TestiAtla) {
    & $exeOut -Test
    if ($LASTEXITCODE -ne 0) { throw "Dogrulama basarisiz: exe -Test exit=$LASTEXITCODE" }
    Satir Green "[3/3] Dogrulama GECTI (exe -Test)"
}

Satir Green ('URET TAMAM: ' + $exeOut)
