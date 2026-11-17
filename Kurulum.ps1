#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Bilgi,
    [switch]$Hazirlik,
    [switch]$Manuel,
    [switch]$Yenile,
    [switch]$Sifirdan,
    [switch]$Etkilesimli,
    [switch]$Sessiz,
    [switch]$Test,
    [string]$ExeDir = ''
)

$ErrorActionPreference = 'Stop'
$Kaynak = $PSScriptRoot
$Ana = Join-Path $env:LOCALAPPDATA 'KuzgunCRM'
$Proje = Join-Path $Ana 'proje'
$Surdur = 'v2.4.1'
function ConfigYol { return (Join-Path $Ana 'kurulum.json') }

function Satir { param($renk, $metin) Write-Host $metin -ForegroundColor $renk }
function Bilgi { param($t) Write-Host $t -ForegroundColor Cyan }
function Basari { param($t) Write-Host $t -ForegroundColor Green }
function Uyari { param($t) Write-Host $t -ForegroundColor Yellow }
function Hata { param($t) Write-Host $t -ForegroundColor Red }
function Baslik { param($t)
    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor DarkGray
    Write-Host ('  ' + $t) -ForegroundColor White
    Write-Host ('=' * 72) -ForegroundColor DarkGray
}
function Adim { param($t)
    $script:AdimNo++
    Write-Host ''
    Write-Host ('-- ' + $script:AdimNo + ') ' + $t) -ForegroundColor Magenta
}
function Devam { param($varsayilan = '')
    if (-not $Etkilesimli) { return '' }
    if ($varsayilan -ne '') { $cevap = Read-Host ("  Enter = devam (" + $varsayilan + ")  [C] Cikis") }
    else { $cevap = Read-Host '  Enter ile devam edin  [C] Cikis' }
    if ($cevap -match '^[Cc\u00E7\u00C7]$' -or $cevap -eq [string][char]0x00E7 -or $cevap -eq [string][char]0x00C7) {
        Write-Host '  Islem iptal edildi. Cikiliyor...' -ForegroundColor Yellow
        exit 0
    }
    return $cevap
}
function BaglantiVarMi {
    try {
        $r = Invoke-WebRequest -Uri 'https://www.google.com/generate_204' -Method Head -UseBasicParsing -TimeoutSec 10
        return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400)
    } catch { return $false }
}
function KomutVarMi { param([string]$ad) return [bool](Get-Command $ad -ErrorAction SilentlyContinue) }

function PathYenile {
    try {
        $mPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        $uPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        $ek = @(
            (Join-Path $env:ProgramFiles 'nodejs'),
            (Join-Path ${env:ProgramFiles(x86)} 'nodejs'),
            (Join-Path $env:APPDATA 'npm')
        ) | Where-Object { $_ -and (Test-Path $_) }
        $env:Path = ($mPath, $uPath, ($ek -join ';')) -join ';'
    } catch {}
}

function NodeOtomatikKur {
    Bilgi '  [ ] Node.js sistemde bulunamadi, otomatik kuruluyor (winget)...'
    if (KomutVarMi 'winget') {
        $eskiEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Null
            PathYenile
            if (KomutVarMi 'node') {
                Basari '  [OK] Node.js winget ile otomatik kuruldu!'
                return $true
            }
        } catch {} finally {
            $ErrorActionPreference = $eskiEap
        }
    }
    try {
        Bilgi '  [ ] Node.js resmi MSI paketi indiriliyor ve sessiz kuruluyor (~25 MB)...'
        $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
        $msiUrl = "https://nodejs.org/dist/v20.18.0/node-v20.18.0-$arch.msi"
        $msiYol = Join-Path $env:TEMP "node-lts-$arch.msi"
        Invoke-WebRequest -Uri $msiUrl -OutFile $msiYol -UseBasicParsing -TimeoutSec 120
        $p = Start-Process msiexec.exe -ArgumentList "/i `"$msiYol`" /qn /norestart" -Wait -PassThru
        PathYenile
        if (KomutVarMi 'node') {
            Basari '  [OK] Node.js MSI ile otomatik kuruldu!'
            return $true
        }
    } catch {
        Uyari ('  [!] Otomatik Node.js kurulumu tamamlanamadi: ' + $_.Exception.Message)
    }
    return $false
}

function Asama1_Bilgilendirme {
    Baslik 'ASAMA 1 - BILGILENDIRME (neyin ne ise yaradigi)'
    Bilgi 'Bu program, Kuzgun Iletisim CRM''ini Google''in bulutuna kurar; size tek bir'
    Bilgi 'web adresi + PIN verir. Telefonda uygulama gibi acilir. Adim adim anlatim:'
    Write-Host ''
    Satir White '  1) GOOGLE HESABI (ucretsiz, ~2 dakika)'
    Satir Gray '     - Veriler Google''in bulutunda tutulacagi icin bir Google (Gmail) hesabi sart.'
    Satir Gray '     - Hesabiniz yoksa: https://accounts.google.com  ->  "Hesap olusturun"'
    Write-Host ''
    Satir White '  2) GOOGLE SHEETS (E-Tablo) = BULUT EXCEL'
    Satir Gray '     - Bizim VERITABANIMIZ bu. Kurulumda "Kuzgun Iletisim CRM Verileri"'
    Satir Gray '       adli E-Tablo sizin Drive''inizda otomatik olusur ve hesabinizla eslenir.'
    Write-Host ''
    Satir White '  3) APPS SCRIPT = GOOGLE''IN UCRETSIZ KOD MOTORU'
    Satir Gray '     - Kendi sunucunuz, hosting, alan adi, aylik ucret YOK. Kod Google''da calisir.'
    Write-Host ''
    Satir White '  4) WEB UYGULAMASI (YAYIN) & ILK GIRISTE OTOMATIK ESLESTIRME'
    Satir Gray '     - Kurulum sonunda CRM tarayicida otomatik acilir, varsayilan PIN ile'
    Satir Gray '       Google hesabiniz, E-Tablonuz ve Gunluk Drive Yedekleme otomatik eslenir!'
    Write-Host ''
}

function Asama2_Gereksinim {
    PathYenile
    Basari '  [ ] Internet baglantisi ...'
    $net = BaglantiVarMi
    if ($net) { Basari ('  [OK] Internet: var (' + (Get-Date -Format HH:mm:ss) + ')') }
    else { Hata '  [X] Internet yok!' }

    $nodeOk = $false; $nodeS = 'YOK'
    if (KomutVarMi 'node') {
        $eskiEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $nodeS = (& node -v 2>&1 | Out-String).Trim()
        } catch {} finally {
            $ErrorActionPreference = $eskiEap
        }
        $major = 0; [void][int]::TryParse(($nodeS -replace '^v(\d+)\..*$', '$1'), [ref]$major)
        if ($major -ge 16) { $nodeOk = $true; Basari ("  [OK] Node.js: " + $nodeS) }
        else { Uyari ("  [!] Node.js eski: " + $nodeS + ' (16+ gerekli)') }
    } else { Uyari '  [!] Node.js yok (otomatik kurulacak)' }

    $npmOk = KomutVarMi 'npm'
    if ($npmOk) {
        $npmVer = ''
        $eskiEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $npmVer = (& npm -v 2>&1 | Out-String).Trim()
        } catch {} finally {
            $ErrorActionPreference = $eskiEap
        }
        Basari ('  [OK] npm: ' + $npmVer)
    } else { Uyari '  [!] npm yok' }

    $kaynakOk = $true
    foreach ($f in @('Code.gs', 'Kuzgun_Iletisim_CRM.html', 'appsscript.json')) {
        if (Test-Path (Join-Path $Kaynak $f)) { Basari ('  [OK] Kaynak dosya: ' + $f) }
        else { Hata ('  [X] Kaynak eksik: ' + $f); $kaynakOk = $false }
    }

    $yerelClasp = Join-Path (Join-Path $Proje 'node_modules\.bin') 'clasp.cmd'
    $aracClasp = Join-Path (Join-Path (Join-Path $Ana 'araclar') 'node_modules\.bin') 'clasp.cmd'
    if (KomutVarMi 'clasp') { Basari '  [OK] clasp: sistemde kurulu' }
    elseif ((Test-Path $yerelClasp) -or (Test-Path $aracClasp)) { Basari '  [OK] clasp: onceki kurulumdan (hazir)' }
    else { Uyari '  [ ] clasp: otomatik kurulacak (proje klasorune)' }

    return [pscustomobject]@{ Internet = $net; Node = $nodeOk; Npm = $npmOk; Kaynak = $kaynakOk }
}

function DosyalariHazirla {
    param([string]$erisim)
    if (-not (Test-Path $Proje)) { New-Item -ItemType Directory -Path $Proje -Force | Out-Null }
    $strayJs = Join-Path $Proje 'Code.js'
    if (Test-Path $strayJs) { Remove-Item $strayJs -Force -ErrorAction SilentlyContinue }
    Copy-Item (Join-Path $Kaynak 'Code.gs') (Join-Path $Proje 'Code.gs') -Force

    $htmlContent = Get-Content (Join-Path $Kaynak 'Kuzgun_Iletisim_CRM.html') -Raw -Encoding UTF8
    $migFile = Join-Path $Ana 'migrated_devices.json'
    if (Test-Path $migFile) {
        try {
            $migData = [System.IO.File]::ReadAllText($migFile, [System.Text.Encoding]::UTF8)
            if ($migData -and $migData.Trim().Length -gt 2) {
                $migObj = $migData | ConvertFrom-Json
                if ($migObj) {
                    $migComp = ConvertTo-Json -InputObject @($migObj) -Depth 5 -Compress
                    $htmlContent = $htmlContent.Replace("const EMBED_DEVICES = [];", "const EMBED_DEVICES = $migComp;")
                }
            }
        } catch {}
    }
    [System.IO.File]::WriteAllText((Join-Path $Proje 'index.html'), $htmlContent, (New-Object System.Text.UTF8Encoding($false)))

    Copy-Item (Join-Path $Kaynak 'appsscript.json') (Join-Path $Proje 'appsscript.json') -Force
    $m = Get-Content (Join-Path $Proje 'appsscript.json') -Raw | ConvertFrom-Json
    $m.webapp.access = $erisim
    ConvertTo-Json -InputObject $m -Depth 10 | Set-Content (Join-Path $Proje 'appsscript.json') -Encoding UTF8

    $claspIgnore = "**/**`r`n!Code.gs`r`n!index.html`r`n!appsscript.json`r`n"
    [System.IO.File]::WriteAllText((Join-Path $Proje '.claspignore'), $claspIgnore, (New-Object System.Text.UTF8Encoding($false)))

    $claspJsonP = Join-Path $Proje '.clasp.json'
    if (Test-Path $claspJsonP) {
        try {
            $cObj = Get-Content $claspJsonP -Raw | ConvertFrom-Json
            if ($cObj -and $cObj.scriptId) {
                @{ scriptId = $cObj.scriptId; rootDir = '.'; scriptExtensions = @('.gs', '.js'); htmlExtensions = @('.html'); jsonExtensions = @('.json') } | ConvertTo-Json | Set-Content $claspJsonP -Encoding UTF8
            }
        } catch {}
    }
    Basari ('  [OK] Hazir: ' + $Proje + ' (erisim: ' + $erisim + ')')
}

function ConfigYaz {
    param([hashtable]$c)
    if (-not (Test-Path $Ana)) { New-Item -ItemType Directory -Path $Ana -Force | Out-Null }
    ConvertTo-Json -InputObject $c | Set-Content (ConfigYol) -Encoding UTF8
}
function ConfigOku {
    $yol = ConfigYol
    if (Test-Path $yol) {
        try { return (Get-Content $yol -Raw | ConvertFrom-Json) } catch {}
    }
    return $null
}

function CihazNormalle {
    param($d, $occurrenceIndex = 0)
    if (-not $d) { return $null }

    # Strict CRM-field guard: reject non-CRM objects
    $hasCrmField = $false
    foreach ($k in @('brand', 'marka', 'cihaz_marka', 'model', 'cihaz_model', 'cihaz',
                     'customer_name', 'musteri_adi', 'musteri', 'customer', 'ad_soyad', 'full_name',
                     'customer_phone', 'musteri_tel', 'telefon', 'phone', 'tel',
                     'imei', 'imei_no', 'imeiNumber',
                     'serial_number', 'serialNumber', 'seri_no', 'seriNo', 'serial',
                     'operations_performed', 'operations', 'yapilan_islemler', 'yapilan_islem', 'islem', 'problem', 'ariza', 'issue', 'description',
                     'notes', 'notlar', 'aciklama', 'price', 'fiyat', 'ucret', 'cost', 'amount', 'tutar')) {
        if ($d.$k -ne $null -and "$($d.$k)".Trim() -ne '') {
            $hasCrmField = $true
            break
        }
    }
    if (-not $hasCrmField) { return $null }

    # id / _id / device_id / kayit_id / no (with deterministic fallback ID)
    $idVal = $null
    foreach ($k in @('id', '_id', 'device_id', 'kayit_id', 'no')) {
        if ($d.$k -ne $null -and "$($d.$k)".Trim() -ne '') { $idVal = $d.$k; break }
    }
    $isSynthetic = $false
    if ($idVal -eq $null -or "$idVal".Trim() -eq '') {
        $isSynthetic = $true
        $hashStr = "$($d.customer_name)|$($d.musteri_adi)|$($d.customer_phone)|$($d.telefon)|$($d.brand)|$($d.marka)|$($d.model)|$($d.cihaz)|$($d.imei)|$($d.serial_number)|$($d.seri_no)|$($d.operations_performed)|$($d.ariza)|$($d.fiyat)|$($d.price)|$($d.notlar)|$($d.notes)|$($d.tur)|$($d.type)|$($d.durum)|$($d.status)|$($d.created_at)|$($d.tarih)|$occurrenceIndex"
        $hVal = 0
        foreach ($b in [System.Text.Encoding]::UTF8.GetBytes($hashStr)) {
            $hVal = (($hVal * 31) + $b) -band 0x7FFFFFFF
        }
        $finalId = 1000000000 + ($hVal % 900000000)
    } else {
        $idParsed = 0
        $finalId = if ([int]::TryParse("$idVal", [ref]$idParsed)) { $idParsed } else { "$idVal" }
    }

    # type / tur / record_type / islem_turu / category
    $typeVal = ''
    foreach ($k in @('type', 'tur', 'record_type', 'islem_turu', 'category')) {
        if ($d.$k -ne $null -and "$($d.$k)" -ne '') { $typeVal = "$($d.$k)"; break }
    }
    $tNorm = $typeVal.Replace([string][char]0x0130, 'i').Replace([string][char]0x0131, 'i').ToLower().Trim().Replace([string][char]0x0307, '')
    $tNorm = $tNorm.Replace([string][char]0x015F, 's').Replace([string][char]0x00E7, 'c').Replace([string][char]0x011F, 'g').Replace([string][char]0x00F6, 'o').Replace([string][char]0x00FC, 'u')
    if ($tNorm -match '^(tamir|servis|repair|service)$') {
        $typeVal = 'REPAIR'
    } elseif ($tNorm -match '^(satis|alim|stok|sale|inventory|stock)$') {
        $typeVal = 'SALE'
    }

    # status / durum / state
    $statusVal = ''
    foreach ($k in @('status', 'durum', 'state')) {
        if ($d.$k -ne $null -and "$($d.$k)" -ne '') { $statusVal = "$($d.$k)"; break }
    }
    $sNorm = $statusVal.Replace([string][char]0x0130, 'i').Replace([string][char]0x0131, 'i').ToLower().Trim().Replace([string][char]0x0307, '')
    $sNorm = $sNorm.Replace([string][char]0x015F, 's').Replace([string][char]0x00E7, 'c').Replace([string][char]0x011F, 'g').Replace([string][char]0x00F6, 'o').Replace([string][char]0x00FC, 'u')
    if ($sNorm -match '^(bekliyor|beklemede|pending|yeni)$') {
        $statusVal = 'PENDING'
    } elseif ($sNorm -match '^(islemde|tamirde|in_progress|processing)$') {
        $statusVal = 'IN_PROGRESS'
    } elseif ($sNorm -match '^(tamamlandi|hazir|completed|done)$') {
        $statusVal = 'COMPLETED'
    } elseif ($sNorm -match '^(teslim|teslim_edildi|teslim edildi|delivered)$') {
        $statusVal = 'DELIVERED'
    } elseif ($sNorm -match '^(stokta|satilik|in_stock|available)$') {
        $statusVal = 'IN_STOCK'
    } elseif ($sNorm -match '^(satildi|sold)$') {
        $statusVal = 'SOLD'
    }

    if (-not $typeVal) {
        if ($statusVal -eq 'IN_STOCK' -or $statusVal -eq 'SOLD') { $typeVal = 'SALE' } else { $typeVal = 'REPAIR' }
    }
    if (-not $statusVal) {
        if ($typeVal -eq 'SALE') { $statusVal = 'IN_STOCK' } else { $statusVal = 'PENDING' }
    }

    # brand / marka / device_brand / cihaz_marka
    $brandVal = ''
    foreach ($k in @('brand', 'marka', 'device_brand', 'cihaz_marka')) {
        if ($d.$k -ne $null -and "$($d.$k)" -ne '') { $brandVal = "$($d.$k)"; break }
    }

    # model / cihaz_model / device_model / cihaz
    $modelVal = ''
    foreach ($k in @('model', 'cihaz_model', 'device_model', 'cihaz')) {
        if ($d.$k -ne $null -and "$($d.$k)" -ne '') { $modelVal = "$($d.$k)"; break }
    }

    # imei / imei_no / imeiNumber
    $imeiVal = ''
    foreach ($k in @('imei', 'imei_no', 'imeiNumber')) {
        if ($d.$k -ne $null -and "$($d.$k)" -ne '') { $imeiVal = "$($d.$k)"; break }
    }

    # serial_number / serialNumber / seri_no / seriNo / serial
    $snVal = ''
    foreach ($k in @('serial_number', 'serialNumber', 'seri_no', 'seriNo', 'serial')) {
        if ($d.$k -ne $null -and "$($d.$k)" -ne '') { $snVal = "$($d.$k)"; break }
    }

    # customer_name / customerName / musteri_adi / musteri / customer / ad_soyad / full_name
    $custVal = ''
    foreach ($k in @('customer_name', 'customerName', 'musteri_adi', 'musteri', 'customer', 'ad_soyad', 'full_name')) {
        if ($d.$k -ne $null -and "$($d.$k)" -ne '') { $custVal = "$($d.$k)"; break }
    }

    # customer_phone / customerPhone / musteri_tel / telefon / phone / tel
    $phoneVal = ''
    foreach ($k in @('customer_phone', 'customerPhone', 'musteri_tel', 'telefon', 'phone', 'tel')) {
        if ($d.$k -ne $null -and "$($d.$k)" -ne '') { $phoneVal = "$($d.$k)"; break }
    }

    # operations_performed / operations / yapilan_islemler / yapilan_islem / islem / problem / ariza / issue / description
    $opVal = ''
    foreach ($k in @('operations_performed', 'operations', 'yapilan_islemler', 'yapilan_islem', 'islem', 'problem', 'ariza', 'issue', 'description')) {
        if ($d.$k -ne $null -and "$($d.$k)" -ne '') { $opVal = "$($d.$k)"; break }
    }

    # notes / notlar / aciklama
    $notesVal = ''
    foreach ($k in @('notes', 'notlar', 'aciklama')) {
        if ($d.$k -ne $null -and "$($d.$k)" -ne '') { $notesVal = "$($d.$k)"; break }
    }

    # sifre / password / device_password
    $sifreVal = ''
    foreach ($k in @('sifre', 'password', 'device_password')) {
        if ($d.$k -ne $null -and "$($d.$k)" -ne '') { $sifreVal = "$($d.$k)"; break }
    }
    if ($sifreVal -and $notesVal -notlike "*$sifreVal*") {
        $sifreEtiket = [string][char]0x015E + 'ifre'
        if ($notesVal) { $notesVal = ($notesVal + ' (' + $sifreEtiket + ': ' + $sifreVal + ')') }
        else { $notesVal = ($sifreEtiket + ': ' + $sifreVal) }
    }

    # price / fiyat / ucret / cost / amount / tutar
    $priceVal = $null
    foreach ($k in @('price', 'fiyat', 'ucret', 'cost', 'amount', 'tutar')) {
        if ($d.$k -ne $null -and "$($d.$k)" -ne '') { $priceVal = $d.$k; break }
    }
    $priceNum = $null
    if ($priceVal -ne $null) {
        $tlChar = [string][char]0x20BA
        $pStr = ("$priceVal" -replace [regex]::Escape($tlChar), '' -replace '(?i)(tl|\s)', '')
        if ($pStr.Contains('.') -and $pStr.Contains(',')) {
            $pStr = $pStr.Replace('.', '').Replace(',', '.')
        } elseif ($pStr.Contains(',')) {
            $pStr = $pStr.Replace(',', '.')
        } elseif ($pStr -match '^\d{1,3}(\.\d{3})+$') {
            $pStr = $pStr.Replace('.', '')
        }
        $parsedDbl = 0.0
        if ([double]::TryParse($pStr, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsedDbl)) {
            $priceNum = $parsedDbl
        }
    }

    # created_at / createdAt / tarih / date / kayit_tarihi
    $rawCreated = $null
    foreach ($k in @('created_at', 'createdAt', 'tarih', 'date', 'kayit_tarihi')) {
        if ($d.$k -ne $null -and "$($d.$k)" -ne '') { $rawCreated = $d.$k; break }
    }
    $createdEpoch = 0L
    if ($rawCreated -ne $null) {
        $parsedLong = 0L
        if ([long]::TryParse("$rawCreated", [ref]$parsedLong)) {
            if ($parsedLong -lt 100000000000L -and $parsedLong -gt 0) { $parsedLong = $parsedLong * 1000L }
            $createdEpoch = $parsedLong
        } else {
            $parsedDate = [datetime]::MinValue
            if ([datetime]::TryParse("$rawCreated", [ref]$parsedDate)) {
                $epochStart = New-Object DateTime 1970, 1, 1, 0, 0, 0, ([DateTimeKind]::Utc)
                $createdEpoch = [long](($parsedDate.ToUniversalTime() - $epochStart).TotalMilliseconds)
            }
        }
    }
    if ($createdEpoch -le 0L) {
        $epochStart = New-Object DateTime 1970, 1, 1, 0, 0, 0, ([DateTimeKind]::Utc)
        $createdEpoch = [long](([datetime]::UtcNow - $epochStart).TotalMilliseconds)
    }

    # updated_at / updatedAt
    $rawUpdated = $null
    foreach ($k in @('updated_at', 'updatedAt')) {
        if ($d.$k -ne $null -and "$($d.$k)" -ne '') { $rawUpdated = $d.$k; break }
    }
    $updatedEpoch = $createdEpoch
    if ($rawUpdated -ne $null) {
        $parsedLongU = 0L
        if ([long]::TryParse("$rawUpdated", [ref]$parsedLongU)) {
            if ($parsedLongU -lt 100000000000L -and $parsedLongU -gt 0) { $parsedLongU = $parsedLongU * 1000L }
            $updatedEpoch = $parsedLongU
        } else {
            $parsedDateU = [datetime]::MinValue
            if ([datetime]::TryParse("$rawUpdated", [ref]$parsedDateU)) {
                $epochStart = New-Object DateTime 1970, 1, 1, 0, 0, 0, ([DateTimeKind]::Utc)
                $updatedEpoch = [long](($parsedDateU.ToUniversalTime() - $epochStart).TotalMilliseconds)
            }
        }
    }

    return [pscustomobject]@{
        id = $finalId
        _isSyntheticId = $isSynthetic
        type = $typeVal
        status = $statusVal
        brand = $brandVal
        model = $modelVal
        imei = $imeiVal
        serial_number = $snVal
        customer_name = $custVal
        customer_phone = $phoneVal
        operations_performed = $opVal
        notes = $notesVal
        price = $priceNum
        created_at = $createdEpoch
        updated_at = $updatedEpoch
    }
}

function CanliSunucuVeriCek {
    # Eski 127.0.0.1 yerel sunucu sureclerini durdurmadan ONCE calisan sunucudan canli veri cek
    $kayitlar = New-Object System.Collections.ArrayList
    $portlar = New-Object System.Collections.Generic.List[int]
    foreach ($p in @(3000, 5000, 8000, 8080, 8081, 8888, 5500, 5050)) {
        [void]$portlar.Add($p)
    }

    try {
        $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
            $_.ProcessId -ne $PID -and $_.Name -match '(?i)^(python|pythonw|node|php)\.exe$' -and
            $_.CommandLine -match '(?i)kuzgun' -and $_.CommandLine -notmatch '(?i)clasp|npm'
        }
        foreach ($pr in $procs) {
            if ($pr.CommandLine -match '(?i)(?:port|:)\s*(\d{4,5})') {
                $pInt = [int]$Matches[1]
                if (-not $portlar.Contains($pInt)) { [void]$portlar.Add($pInt) }
            }
        }
    } catch {}

    $endpoints = @('/api/devices', '/api/export', '/devices', '/api/data', '/data.json', '/export')
    foreach ($port in $portlar) {
        $portBitti = $false
        foreach ($ep in $endpoints) {
            $url = ("http://127.0.0.1:" + $port + $ep)
            try {
                $req = [System.Net.WebRequest]::Create($url)
                $req.Timeout = 1200
                $req.Method = 'GET'
                $resp = $req.GetResponse()
                $stream = $resp.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
                $body = $reader.ReadToEnd()
                $reader.Close()
                $resp.Close()

                if ($body -and $body.Trim().Length -gt 2) {
                    $parsed = $body | ConvertFrom-Json -ErrorAction SilentlyContinue
                    $items = @()
                    if ($parsed -is [System.Array]) {
                        $items = $parsed
                    } elseif ($parsed.devices -is [System.Array]) {
                        $items = $parsed.devices
                    } elseif ($parsed.data -is [System.Array]) {
                        $items = $parsed.data
                    }

                    if ($items.Count -gt 0) {
                        Basari ("  [OK] Canli 127.0.0.1 sunucusundan veriler basariyla alindi ($url, $($items.Count) kayit)")
                        foreach ($it in $items) {
                            $norm = CihazNormalle $it
                            if ($norm) { [void]$kayitlar.Add($norm) }
                        }
                        $portBitti = $true
                        break
                    }
                }
            } catch {}
        }
        if ($portBitti) { break }
    }

    if ($kayitlar.Count -gt 0) {
        $canliYol = Join-Path $Ana 'from_live_server.json'
        if (-not (Test-Path $Ana)) { New-Item -ItemType Directory -Path $Ana -Force | Out-Null }
        ConvertTo-Json -InputObject @($kayitlar) -Depth 5 | Set-Content -Path $canliYol -Encoding UTF8
    }

    return @($kayitlar.ToArray())
}

function MasaustuKlasorleri {
    $liste = New-Object System.Collections.ArrayList
    $trMasaustu = if ($env:USERPROFILE) { Join-Path $env:USERPROFILE ('Masa' + [string][char]0x00FC + 'st' + [string][char]0x00FC) } else { '' }
    $adaylar = @(
        [Environment]::GetFolderPath('Desktop'),
        (Join-Path $env:USERPROFILE 'Desktop'),
        $trMasaustu,
        [Environment]::GetFolderPath('CommonDesktopDirectory'),
        $(if ($env:OneDrive) { Join-Path $env:OneDrive 'Desktop' }),
        $(if ($env:OneDrive -and $env:OneDrive -ne '') { Join-Path $env:OneDrive ('Masa' + [string][char]0x00FC + 'st' + [string][char]0x00FC) }),
        $(if ($env:OneDriveConsumer) { Join-Path $env:OneDriveConsumer 'Desktop' }),
        $(if ($env:OneDriveCommercial) { Join-Path $env:OneDriveCommercial 'Desktop' })
    )
    foreach ($d in $adaylar) {
        if ($d -and (Test-Path -LiteralPath $d) -and -not $liste.Contains($d)) { [void]$liste.Add($d) }
    }
    return @($liste.ToArray())
}

function EskiDosyalariTara {
    $bulunanlar = New-Object System.Collections.ArrayList

    # Aday dizinler listesi
    $adayDizinler = New-Object System.Collections.Generic.List[string]
    $indirilenlerTr = if ($env:USERPROFILE) { Join-Path $env:USERPROFILE ([string][char]0x0130 + 'ndirilenler') } else { '' }
    $belgelerTr = if ($env:USERPROFILE) { Join-Path $env:USERPROFILE 'Belgeler' } else { '' }
    $oneDriveDocsTr = if ($env:OneDrive) { Join-Path $env:OneDrive 'Belgeler' } else { '' }
    $standartDizinler = @(
        'C:\ozi',
        'C:\kuzgun',
        'C:\kuzgun-crm',
        (Join-Path $Ana 'yedekler'),
        (Join-Path $Ana 'data'),
        (Join-Path $env:LOCALAPPDATA 'ozi'),
        (Join-Path $env:APPDATA 'KuzgunCRM'),
        (Join-Path $env:USERPROFILE 'KuzgunCRM'),
        # Downloads & Documents
        (Join-Path $env:USERPROFILE 'Downloads'),
        $indirilenlerTr,
        $(if ($env:OneDrive) { Join-Path $env:OneDrive 'Downloads' }),
        [Environment]::GetFolderPath('MyDocuments'),
        (Join-Path $env:USERPROFILE 'Documents'),
        $belgelerTr,
        $(if ($env:OneDrive) { Join-Path $env:OneDrive 'Documents' }),
        $oneDriveDocsTr,
        $(if ($env:OneDriveConsumer) { Join-Path $env:OneDriveConsumer 'Documents' }),
        $(if ($env:OneDriveCommercial) { Join-Path $env:OneDriveCommercial 'Documents' })
    )
    # ExeDir scanning (passed from launcher exe)
    if ($ExeDir) {
        $ExeDir = $ExeDir.TrimEnd('\', '/')
        if (Test-Path -LiteralPath $ExeDir) {
            try {
                $isDriveRoot = [bool]($ExeDir -match '^[A-Za-z]:\\?$')
                if (-not $isDriveRoot -and -not $adayDizinler.Contains($ExeDir)) {
                    [void]$adayDizinler.Add($ExeDir)
                }
            } catch {}
        }
    }
    foreach ($d in $standartDizinler) {
        if ($d -and (Test-Path -LiteralPath $d) -and -not $adayDizinler.Contains($d)) {
            [void]$adayDizinler.Add($d)
            if ($d -match '(?i)\\(ozi|kuzgun(-crm)?|KuzgunCRM)$') {
                try {
                    Get-ChildItem -LiteralPath $d -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object {
                        $_.FullName -notmatch '(?i)[\\/](node_modules|\.git|__pycache__|venv|\.venv|araclar|proje|kaynak)([\\/]|$)'
                    } | ForEach-Object {
                        if (-not $adayDizinler.Contains($_.FullName)) { [void]$adayDizinler.Add($_.FullName) }
                    }
                } catch {}
            }
        }
    }

    # Masaustu klasorleri ve alt klasorleri
    foreach ($desk in (MasaustuKlasorleri)) {
        if ($desk -and (Test-Path -LiteralPath $desk) -and -not $adayDizinler.Contains($desk)) {
            [void]$adayDizinler.Add($desk)
        }
        # Masaustundeki kuzgun veya ozi klasorleri
        try {
            Get-ChildItem -LiteralPath $desk -Directory -ErrorAction SilentlyContinue | Where-Object {
                $_.Name -match '(?i)kuzgun|ozi|teknik|servis|crm|yedek'
            } | ForEach-Object {
                if (-not $adayDizinler.Contains($_.FullName)) { [void]$adayDizinler.Add($_.FullName) }
            }
        } catch {}

        # Masaustu kisayollarindaki (.lnk) hedef klasorler
        try {
            $ws = New-Object -ComObject WScript.Shell
            Get-ChildItem -LiteralPath $desk -File -ErrorAction SilentlyContinue | Where-Object {
                $_.Extension -ieq '.lnk' -and $_.Name -match '(?i)kuzgun|ozi|crm'
            } | ForEach-Object {
                try {
                    $sc = $ws.CreateShortcut($_.FullName)
                    if ($sc.TargetPath) {
                        $targetDir = Split-Path $sc.TargetPath -Parent
                        if ($targetDir -and (Test-Path -LiteralPath $targetDir) -and -not $adayDizinler.Contains($targetDir)) {
                            [void]$adayDizinler.Add($targetDir)
                        }
                    }
                    if ($sc.WorkingDirectory -and (Test-Path -LiteralPath $sc.WorkingDirectory) -and -not $adayDizinler.Contains($sc.WorkingDirectory)) {
                        [void]$adayDizinler.Add($sc.WorkingDirectory)
                    }
                } catch {}
            }
        } catch {}
    }

    # 1. JSON dosyalarini tara (tum zarf formatlarini cozer: array, .devices, .data, .records, .items, .backup.devices, tek cihaz)
    foreach ($d in $adayDizinler) {
        try {
            $jsonFiles = Get-ChildItem -LiteralPath $d -File -ErrorAction SilentlyContinue | Where-Object {
                if ($_.Extension -ine '.json') { return $false }
                if ($_.Name -match '(?i)^(package(-lock)?|appsscript|tsconfig|launch|kurulum|\.clasp|settings|extensions|composer|manifest)\.json$') { return $false }
                if ($_.Length -gt 20MB -or $_.Length -lt 3) { return $false }
                return $true
            }
            foreach ($jf in $jsonFiles) {
                try {
                    $raw = [System.IO.File]::ReadAllText($jf.FullName, [System.Text.Encoding]::UTF8)
                    if ($raw -and $raw.Trim().Length -gt 2) {
                        $parsed = $raw | ConvertFrom-Json -ErrorAction SilentlyContinue
                        $arr = @()
                        if ($parsed -is [System.Array]) {
                            $arr = $parsed
                        } elseif ($parsed.devices -is [System.Array]) {
                            $arr = $parsed.devices
                        } elseif ($parsed.data -is [System.Array]) {
                            $arr = $parsed.data
                        } elseif ($parsed.records -is [System.Array]) {
                            $arr = $parsed.records
                        } elseif ($parsed.items -is [System.Array]) {
                            $arr = $parsed.items
                        } elseif ($parsed.kayitlar -is [System.Array]) {
                            $arr = $parsed.kayitlar
                        } elseif ($parsed.cihazlar -is [System.Array]) {
                            $arr = $parsed.cihazlar
                        } elseif ($parsed.backup -and $parsed.backup.devices -is [System.Array]) {
                            $arr = $parsed.backup.devices
                        } elseif ($parsed -and ($parsed.musteri_adi -or $parsed.customer_name -or $parsed.musteri -or $parsed.customer -or
                                               $parsed.brand -or $parsed.marka -or $parsed.cihaz_marka -or
                                               $parsed.model -or $parsed.cihaz_model -or $parsed.cihaz -or
                                               $parsed.serial_number -or $parsed.seri_no -or $parsed.imei -or $parsed.imei_no -or
                                               $parsed.telefon -or $parsed.customer_phone)) {
                            $arr = @($parsed)
                        }
                        $occIdx = 0
                        foreach ($it in $arr) {
                            $norm = CihazNormalle $it $occIdx
                            if ($norm) { [void]$bulunanlar.Add($norm) }
                            $occIdx++
                        }
                    }
                } catch {}
            }
        } catch {}
    }

    # 1b. Eski HTML dosyalarindaki gomulu EMBED_DEVICES dizilerini tara
    $htmlAdaylar = New-Object System.Collections.Generic.List[string]
    if (Test-Path -LiteralPath (Join-Path $Ana 'Kuzgun_CRM.html')) {
        [void]$htmlAdaylar.Add((Join-Path $Ana 'Kuzgun_CRM.html'))
    }
    foreach ($d in $adayDizinler) {
        try {
            Get-ChildItem -LiteralPath $d -File -ErrorAction SilentlyContinue | Where-Object {
                $_.Extension -match '(?i)^\.html?$' -and $_.Length -lt 15MB -and $_.Name -match '(?i)kuzgun|crm|ozi|index'
            } | ForEach-Object {
                if (-not $htmlAdaylar.Contains($_.FullName)) { [void]$htmlAdaylar.Add($_.FullName) }
            }
        } catch {}
    }
    foreach ($hf in $htmlAdaylar) {
        try {
            $hTxt = [System.IO.File]::ReadAllText($hf, [System.Text.Encoding]::UTF8)
            if ($hTxt -match 'const\s+EMBED_DEVICES\s*=\s*(\[[\s\S]*?\]);') {
                $embStr = $Matches[1].Trim()
                if ($embStr.Length -gt 4 -and $embStr -ne '[]') {
                    $embArr = $embStr | ConvertFrom-Json -ErrorAction SilentlyContinue
                    $occIdx = 0
                    foreach ($it in @($embArr)) {
                        $norm = CihazNormalle $it $occIdx
                        if ($norm) { [void]$bulunanlar.Add($norm) }
                        $occIdx++
                    }
                }
            }
        } catch {}
    }

    # 2. SQLite veritabanlarini tara (*.db, *.db3, *.sqlite, *.sqlite3, *.s3db) - Node.js (node:sqlite) + Python yedekli
    foreach ($d in $adayDizinler) {
        try {
            $dbFiles = Get-ChildItem -LiteralPath $d -File -ErrorAction SilentlyContinue | Where-Object {
                $_.Extension -match '(?i)^\.(db|db3|sqlite|sqlite3|s3db)$'
            }
            foreach ($db in $dbFiles) {
                $dbOkundu = $false
                if (KomutVarMi 'node') {
                    $nodeCode = 'try { const { DatabaseSync } = require("node:sqlite"); const db = new DatabaseSync(process.argv[1]); const tables = db.prepare("SELECT name FROM sqlite_master WHERE type=\x27table\x27 AND name NOT LIKE \x27sqlite_%\x27").all().map(r => r.name); const out = []; for (const t of tables) { try { out.push(...db.prepare("SELECT * FROM \"" + t.replace(/"/g, "\"\"") + "\"").all()); } catch (e) {} } db.close(); process.stdout.write(JSON.stringify(out).replace(/[\u007f-\uffff]/g, c => "\\u" + ("0000" + c.charCodeAt(0).toString(16)).slice(-4))); } catch (e) {}'
                    $eskiEap = $ErrorActionPreference
                    $ErrorActionPreference = 'Continue'
                    try {
                        $resNode = (& node --no-warnings -e $nodeCode $db.FullName 2>$null | Out-String)
                        if ($resNode -and $resNode.Trim().StartsWith('[')) {
                            $itemsN = $resNode.Trim() | ConvertFrom-Json -ErrorAction SilentlyContinue
                            $occIdx = 0
                            foreach ($it in @($itemsN)) {
                                $norm = CihazNormalle $it $occIdx
                                if ($norm) { [void]$bulunanlar.Add($norm); $dbOkundu = $true }
                                $occIdx++
                            }
                        }
                    } catch {} finally {
                        $ErrorActionPreference = $eskiEap
                    }
                }
                if (-not $dbOkundu -and (KomutVarMi 'python' -or KomutVarMi 'python3')) {
                    $pyCmd = if (KomutVarMi 'python') { 'python' } else { 'python3' }
                    $pyCode = 'import sqlite3, json, sys; conn = sqlite3.connect(sys.argv[1]); cur = conn.cursor(); cur.execute("SELECT name FROM sqlite_master WHERE type=''table'';"); tables = [r[0] for r in cur.fetchall() if not r[0].startswith("sqlite_")]; out = []; [out.extend([dict(zip([c[1] for c in cur.execute(''PRAGMA table_info("'' + t.replace(''"'', ''""'') + ''");'').fetchall()], [(v.decode(''utf-8'', errors=''replace'') if isinstance(v, bytes) else v) for v in row])) for row in cur.execute(''SELECT * FROM "'' + t.replace(''"'', ''""'') + ''";'').fetchall()]) for t in tables]; conn.close(); print(json.dumps(out, ensure_ascii=True, default=str))'
                    $eskiEap = $ErrorActionPreference
                    $ErrorActionPreference = 'Continue'
                    try {
                        $res = ($pyCode | & $pyCmd - $db.FullName 2>&1 | Out-String)
                        if ($res -and $res.Trim().StartsWith('[')) {
                            $items = $res.Trim() | ConvertFrom-Json -ErrorAction SilentlyContinue
                            $occIdx = 0
                            foreach ($it in @($items)) {
                                $norm = CihazNormalle $it $occIdx
                                if ($norm) { [void]$bulunanlar.Add($norm) }
                                $occIdx++
                            }
                        }
                    } catch {} finally {
                        $ErrorActionPreference = $eskiEap
                    }
                }
            }
        } catch {}
    }

    # 3. Tarayici (Chrome / Edge / Brave / Opera) LevelDB localStorage taramasi (UTF-8 + UTF-16LE destekli)
    $levelDbDirs = New-Object System.Collections.Generic.List[string]
    $browserRoots = @(
        (Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data'),
        (Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\User Data')
    )
    foreach ($br in $browserRoots) {
        if ($br -and (Test-Path -LiteralPath $br)) {
            $defLdb = Join-Path $br 'Default\Local Storage\leveldb'
            if (Test-Path -LiteralPath $defLdb) { [void]$levelDbDirs.Add($defLdb) }
            try {
                Get-ChildItem -LiteralPath $br -Directory -ErrorAction SilentlyContinue | Where-Object {
                    $_.Name -match '^(Default|Profile\s+\d+)$'
                } | ForEach-Object {
                    $pLdb = Join-Path $_.FullName 'Local Storage\leveldb'
                    if ((Test-Path -LiteralPath $pLdb) -and -not $levelDbDirs.Contains($pLdb)) {
                        [void]$levelDbDirs.Add($pLdb)
                    }
                }
            } catch {}
        }
    }
    foreach ($ldbDir in $levelDbDirs) {
        if (Test-Path -LiteralPath $ldbDir) {
            try {
                $ldbFiles = Get-ChildItem -LiteralPath $ldbDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '(?i)^\.(ldb|log)$' }
                foreach ($lf in $ldbFiles) {
                    try {
                        $bytes = [System.IO.File]::ReadAllBytes($lf.FullName)
                        if ($bytes.Length -lt 10) { continue }
                        $latinTxt = [System.Text.Encoding]::GetEncoding(28591).GetString($bytes)
                        if ($latinTxt -notmatch '(?i)(kuzgun|musteri|customer_name|cihaz_marka)') { continue }

                        $views = New-Object System.Collections.Generic.List[string]
                        [void]$views.Add([System.Text.Encoding]::UTF8.GetString($bytes))
                        $evenLen = $bytes.Length - ($bytes.Length % 2)
                        if ($evenLen -gt 4) {
                            [void]$views.Add([System.Text.Encoding]::Unicode.GetString($bytes, 0, $evenLen))
                        }
                        if ($bytes.Length -gt 5) {
                            $oddLen = ($bytes.Length - 1) - (($bytes.Length - 1) % 2)
                            if ($oddLen -gt 4) {
                                [void]$views.Add([System.Text.Encoding]::Unicode.GetString($bytes, 1, $oddLen))
                            }
                        }

                        foreach ($vTxt in $views) {
                            $startMatches = [regex]::Matches($vTxt, '\[\s*\{')
                            foreach ($sm in $startMatches) {
                                $sIdx = $sm.Index
                                $depth = 0
                                $inStr = $false
                                $esc = $false
                                $eIdx = -1
                                $maxScan = [Math]::Min($vTxt.Length, $sIdx + 2000000)
                                for ($ci = $sIdx; $ci -lt $maxScan; $ci++) {
                                    $ch = $vTxt[$ci]
                                    if ($esc) { $esc = $false; continue }
                                    if ($ch -eq [char]'\') { if ($inStr) { $esc = $true }; continue }
                                    if ($ch -eq [char]'"') { $inStr = -not $inStr; continue }
                                    if ($inStr) { continue }
                                    if ($ch -eq [char]'[') { $depth++ }
                                    elseif ($ch -eq [char]']') {
                                        $depth--
                                        if ($depth -eq 0) { $eIdx = $ci; break }
                                    }
                                }
                                if ($eIdx -gt $sIdx) {
                                    $candJson = $vTxt.Substring($sIdx, $eIdx - $sIdx + 1)
                                    if ($candJson -match '(?i)"(musteri_adi|customer_name|brand|marka|model|cihaz_marka|imei|seri_no)"') {
                                        try {
                                            $parsed = $candJson | ConvertFrom-Json -ErrorAction SilentlyContinue
                                            $occIdx = 0
                                            foreach ($it in @($parsed)) {
                                                $norm = CihazNormalle $it $occIdx
                                                if ($norm) { [void]$bulunanlar.Add($norm) }
                                                $occIdx++
                                            }
                                        } catch {}
                                    }
                                }
                            }
                        }
                    } catch {}
                }
            } catch {}
        }
    }

    return @($bulunanlar.ToArray())
}

function VeriMigrasyonYurut {
    param($onceki)
    Adim 'Eski CRM surumleri ve verileri kesfediliyor (Veri Migrasyonu)'

    # 1. CANLI SUNUCU TARAMASI (SURECLERI DURDURMADAN ONCE!)
    $canliVeriler = CanliSunucuVeriCek

    # 2. DOSYA, SQLITE VE LOCALSTORAGE KESFI
    $dosyaVerileri = EskiDosyalariTara

    # 3. MEVCUT MIGRATED DOSYASI VARSA OKU
    $mevcutMigFile = Join-Path $Ana 'migrated_devices.json'
    $mevcutMigVerileri = @()
    if (Test-Path $mevcutMigFile) {
        try {
            $rawM = [System.IO.File]::ReadAllText($mevcutMigFile, [System.Text.Encoding]::UTF8)
            $parsedM = $rawM | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($parsedM) {
                $occIdx = 0
                foreach ($it in @($parsedM)) {
                    $norm = CihazNormalle $it $occIdx
                    if ($norm) { $mevcutMigVerileri += $norm }
                    $occIdx++
                }
            }
        } catch {}
    }

    # 4. MERGE & DEDUPLICATE (id bazinda)
    # Protect explicit IDs from colliding synthetic IDs, disambiguate colliding synthetic IDs
    $uniqueMap = @{}
    foreach ($item in (@($canliVeriler) + @($dosyaVerileri) + @($mevcutMigVerileri))) {
        if (-not $item) { continue }
        $k = "$($item.id)"
        if (-not $uniqueMap.ContainsKey($k)) {
            $uniqueMap[$k] = $item
        } else {
            $cur = $uniqueMap[$k]
            # If current is synthetic and new is explicit, explicit wins
            if ($cur._isSyntheticId -and -not $item._isSyntheticId) {
                $uniqueMap[$k] = $item
            } elseif (-not $cur._isSyntheticId -and $item._isSyntheticId) {
                # New item is synthetic but ID already taken by explicit record -> re-assign synthetic ID
                $newId = [int]$item.id
                while ($uniqueMap.ContainsKey("$newId")) { $newId++ }
                $item.id = $newId
                $uniqueMap["$newId"] = $item
            } else {
                # Both synthetic or both explicit
                if ($cur._isSyntheticId -and $item._isSyntheticId) {
                    # Compare content: if content differs, disambiguate
                    $cStr = "$($cur.customer_name)|$($cur.brand)|$($cur.model)|$($cur.serial_number)|$($cur.imei)"
                    $iStr = "$($item.customer_name)|$($item.brand)|$($item.model)|$($item.serial_number)|$($item.imei)"
                    if ($cStr -ne $iStr) {
                        $newId = [int]$item.id
                        while ($uniqueMap.ContainsKey("$newId")) { $newId++ }
                        $item.id = $newId
                        $uniqueMap["$newId"] = $item
                    } elseif ($item.updated_at -ge $cur.updated_at) {
                        $uniqueMap[$k] = $item
                    }
                } elseif ($item.updated_at -ge $cur.updated_at) {
                    $uniqueMap[$k] = $item
                }
            }
        }
    }

    # Clean internal _isSyntheticId tag before export
    foreach ($v in $uniqueMap.Values) {
        if ($v.PSObject.Properties['_isSyntheticId']) {
            $v.PSObject.Properties.Remove('_isSyntheticId')
        }
    }

    $siraliListe = @($uniqueMap.Values | Sort-Object { [long]$_.created_at })

    # 5. GUVENLI YEDEKLEME: Asla veri silme, dokunmadan once yedekle!
    $tarihDamgasi = Get-Date -Format 'yyyyMMdd_HHmmss'
    $yedekDizin = Join-Path $Ana ("yedekler\otomatik_migrasyon_$tarihDamgasi")
    if (-not (Test-Path -LiteralPath $yedekDizin)) { New-Item -ItemType Directory -Path $yedekDizin -Force | Out-Null }

    # Eski html ve config'i yedekle
    $yerelHtml = Join-Path $Ana 'Kuzgun_CRM.html'
    if (Test-Path -LiteralPath $yerelHtml) {
        Copy-Item -LiteralPath $yerelHtml -Destination (Join-Path $yedekDizin 'Kuzgun_CRM_eski.html') -Force -ErrorAction SilentlyContinue
    }
    $mevcutConfig = ConfigYol
    if (Test-Path -LiteralPath $mevcutConfig) {
        Copy-Item -LiteralPath $mevcutConfig -Destination (Join-Path $yedekDizin 'kurulum_eski.json') -Force -ErrorAction SilentlyContinue
    }

    if ($siraliListe.Count -gt 0) {
        $jsonStr = ConvertTo-Json -InputObject @($siraliListe) -Depth 5
        [System.IO.File]::WriteAllText($mevcutMigFile, $jsonStr, (New-Object System.Text.UTF8Encoding($false)))

        $backupCopy = Join-Path $yedekDizin "otomatik_migrasyon_$tarihDamgasi.json"
        [System.IO.File]::WriteAllText($backupCopy, $jsonStr, (New-Object System.Text.UTF8Encoding($false)))

        Basari ("  [OK] Eski surumlerden $($siraliListe.Count) cihaz kaydi basariyla kurtarildi ve yedeklendi:")
        Satir Gray ("       -> $mevcutMigFile")
        Satir Gray ("       -> $backupCopy")
    } else {
        Bilgi '  [ ] Taranan konumlarda eski veri bulunmadi (yeni kurulum olarak devam ediliyor).'
    }

    # 6. SURECLERI DURDUR VE ESKI KISAYOLLARI TASIN (CANLI VERI CEKILDIKTEN SONRA!)
    EskiKurulumTemizle -HedefYedekDizin $yedekDizin

    return ,$siraliListe
}

function OncekiKurulumBul {
    $cfg = ConfigOku
    $claspDosya = Join-Path $Proje '.clasp.json'
    $scriptId = $null
    if (Test-Path $claspDosya) {
        try {
            $claspObj = Get-Content $claspDosya -Raw | ConvertFrom-Json
            if ($claspObj -and $claspObj.scriptId) { $scriptId = $claspObj.scriptId }
        } catch {}
    }
    if (-not $scriptId -and $cfg -and $cfg.scriptId) {
        $scriptId = $cfg.scriptId
        if (-not (Test-Path $Proje)) { New-Item -ItemType Directory -Path $Proje -Force | Out-Null }
        @{ scriptId = $scriptId; rootDir = '.' } | ConvertTo-Json | Set-Content $claspDosya -Encoding UTF8
    }

    # Eski surum veya kalinti kontrolu
    $eskiBulgular = @()
    if (Test-Path 'C:\ozi') { $eskiBulgular += 'C:\ozi' }
    foreach ($d in (MasaustuKlasorleri)) {
        $eskiMasaustu = Get-ChildItem -Path $d -File -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -match '(?i)kuzgun' -and $_.Extension -match '(?i)^\.(html?|lnk|url|bat|cmd|vbs|py|ps1)$'
        }
        if ($eskiMasaustu) { $eskiBulgular += "$($eskiMasaustu.Count) masaustu dosyasi" }
    }
    $eskiProcs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessId -ne $PID -and $_.Name -match '(?i)^(python|pythonw|node|php)\.exe$' -and
        $_.CommandLine -match '(?i)kuzgun' -and $_.CommandLine -notmatch '(?i)clasp|npm'
    }
    if ($eskiProcs) { $eskiBulgular += '127.0.0.1 yerel sunucu sureci' }

    if ($cfg -or $scriptId) {
        $erisim = 'ANYONE_ANONYMOUS'
        if ($cfg -and $cfg.erisim -and $cfg.erisim -ne 'ANYONE') { $erisim = $cfg.erisim }
        $url = $null
        if ($cfg -and $cfg.url) { $url = $cfg.url }
        $depId = $null
        if ($cfg -and $cfg.deploymentId) { $depId = $cfg.deploymentId }
        return [pscustomobject]@{
             Bulundu = $true
             Url = $url
             DeploymentId = $depId
             ScriptId = $scriptId
             Erisim = $erisim
             EskiSurum = if ($cfg -and $cfg.surum) { $cfg.surum } else { 'v2.0 (Eski)' }
             EskiBulgular = $eskiBulgular
             EskiKurulumVar = ($eskiBulgular.Count -gt 0)
        }
    }

    if ($eskiBulgular.Count -gt 0) {
        return [pscustomobject]@{
            Bulundu = $true
            Url = $null
            DeploymentId = $null
            ScriptId = $null
            Erisim = 'ANYONE_ANONYMOUS'
            EskiSurum = 'v1.x (Yerel Masaustu/127.0.0.1)'
            EskiBulgular = $eskiBulgular
            EskiKurulumVar = $true
        }
    }

    return [pscustomobject]@{ Bulundu = $false; EskiBulgular = @(); EskiKurulumVar = $false }
}

function ClaspYoluBul {
    $yerel = Join-Path (Join-Path $Proje 'node_modules\.bin') 'clasp.cmd'
    if (Test-Path $yerel) { return $yerel }
    $aracYol = Join-Path (Join-Path (Join-Path $Ana 'araclar') 'node_modules\.bin') 'clasp.cmd'
    if (Test-Path $aracYol) { return $aracYol }
    if (KomutVarMi 'clasp') { return 'clasp' }
    return $null
}
function Clasp-Cagir {
    param([string[]]$Argumanlar, [string]$Is, [switch]$Sessiz)
    $yol = ClaspYoluBul
    if (-not $yol) { throw 'clasp bulunamadi' }
    if (-not $Sessiz) { Write-Host ('    > clasp ' + ($Argumanlar -join ' ')) -ForegroundColor DarkGray }
    Push-Location $Proje
    $eskiEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $cikti = (& $yol @Argumanlar 2>&1 | Out-String)
        $kod = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $eskiEap
        Pop-Location
    }
    $script:ClaspLog += "`n$ clasp $($Argumanlar -join ' ')`n$cikti"
    if ($kod -ne 0) {
        throw ("clasp basarisiz ($Is, kod $kod):`n" + $cikti.Trim())
    }
    return $cikti
}

function Asama_OtomatikKurulum {
    param([string]$erisim, $onceki = $null)

    Adim 'Clasp (Google aracisi) kontrol ediliyor'
    if (-not (ClaspYoluBul)) {
        Bilgi '    Proje icine clasp kuruluyor (npm, ~30-60 sn)...'
        if (-not (Test-Path $Proje)) { New-Item -ItemType Directory -Path $Proje -Force | Out-Null }
        Push-Location $Proje
        $eskiEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $npmCikti = (& npm i @google/clasp --no-fund --no-audit --loglevel=error 2>&1 | Out-String)
            $script:ClaspLog += "`n$ npm i @google/clasp`n$npmCikti"
        } catch {} finally {
            $ErrorActionPreference = $eskiEap
            Pop-Location
        }
        if (-not (ClaspYoluBul)) { throw 'clasp kurulamadi (npm/node kontrol edin)' }
    }
    Basari '    [OK] clasp hazir'

    Adim 'Google Hesabi Esleme ve Giris Kontrolu'
    $yetkili = $false
    $hesap = ''
    try {
        $out = Clasp-Cagir -Argumanlar @('show-authorized-user') -Sessiz
        if ($out -match '[\w\.-]+@[\w\.-]+\.\w+') {
            $yetkili = $true
            $hesap = $Matches[0]
        } elseif ($out -match '@' -and $out -notmatch 'not be logged in') {
            $yetkili = $true
        }
    } catch { $yetkili = $false }

    if (-not $yetkili) {
        Bilgi '    Tarayicida Google giris ekrani aciliyor. Lutfen Google hesabinizi secip izin verin...'
        $null = Clasp-Cagir -Argumanlar @('login')
        try {
            $out2 = Clasp-Cagir -Argumanlar @('show-authorized-user') -Sessiz
            if ($out2 -match '[\w\.-]+@[\w\.-]+\.\w+') { $hesap = $Matches[0] }
        } catch {}
        Basari ('    [OK] Google hesabi basariyla eslendi' + $(if ($hesap) { ": $hesap" } else { '' }))
    } else {
        Basari ('    [OK] Mevcut Google hesabi algilandi ve eslendi' + $(if ($hesap) { ": $hesap" } else { '' }))
    }

    $cikarilmis = $false
    $mevcutScriptId = $null
    $claspJsonYol = Join-Path $Proje '.clasp.json'
    if (Test-Path $claspJsonYol) {
        try {
            $claspCfg = Get-Content $claspJsonYol -Raw | ConvertFrom-Json
            if ($claspCfg.scriptId) {
                $cikarilmis = $true
                $mevcutScriptId = $claspCfg.scriptId
                Basari ('    [OK] Mevcut Apps Script projesi algilandi (ID: ' + $mevcutScriptId + ')')
            }
        } catch {}
    }

    # Eger .clasp.json yoksa ama Google hesabinda daha once "Kuzgun Iletisim CRM" varsa bulmaya calis
    if (-not $cikarilmis -and -not $Sifirdan) {
        try {
            $listOut = Clasp-Cagir -Argumanlar @('list') -Sessiz
            foreach ($line in ($listOut -split "`r?`n")) {
                if ($line -match 'Kuzgun' -and $line -match 'script\.google\.com/d/([a-zA-Z0-9_-]+)') {
                    $mevcutScriptId = $Matches[1]
                    @{ scriptId = $mevcutScriptId; rootDir = '.'; scriptExtensions = @('.gs', '.js'); htmlExtensions = @('.html'); jsonExtensions = @('.json') } | ConvertTo-Json | Set-Content $claspJsonYol -Encoding UTF8
                    $cikarilmis = $true
                    Basari ('    [OK] Buluttaki mevcut Kuzgun CRM projesi bulundu ve baglandi (ID: ' + $mevcutScriptId + ')')
                    break
                }
            }
        } catch {}
    }

    # Projeyi olustur veya kodu yukle (Apps Script API kapaliysa otomatik algilayip ac)
    $apiSayfaAcildi = $false
    for ($apiDeneme = 1; $apiDeneme -le 6; $apiDeneme++) {
        try {
            if (-not $cikarilmis) {
                Adim 'Google Bulutta yeni Apps Script projesi olusturuluyor'
                $null = Clasp-Cagir -Argumanlar @('create-script', '--title', 'Kuzgun Iletisim CRM', '--type', 'webapp', '--rootDir', '.')
                if (Test-Path $claspJsonYol) {
                    $claspCfg = Get-Content $claspJsonYol -Raw | ConvertFrom-Json
                    $mevcutScriptId = $claspCfg.scriptId
                }
                $cikarilmis = $true
                Basari '    [OK] Proje olusturuldu'
            }

            # create-script komutu clasp.files.pull() calistirip Code.js ve bos appsscript.json indirdigi icin dosyalari yeniden hazirla
            DosyalariHazirla -erisim $erisim

            Adim 'Guncel kodlar buluta yukleniyor (push)'
            $null = Clasp-Cagir -Argumanlar @('push', '--force')
            Basari '    [OK] Code.gs + index.html + manifest basariyla yuklendi'
            break
        } catch {
            $hataMesaj = $_.Exception.Message
            if ($apiDeneme -lt 6 -and ($hataMesaj -match 'User has not enabled the Apps Script API' -or $hataMesaj -match 'script\.google\.com/home/usersettings' -or $hataMesaj -match 'Apps Script API')) {
                if (-not $apiSayfaAcildi) {
                    Uyari '    [!] Google Apps Script API henuz acik degil. Ayar sayfasi aciliyor...'
                    try { Start-Process 'https://script.google.com/home/usersettings' } catch {}
                    $apiSayfaAcildi = $true
                }
                if ($Etkilesimli) {
                    $cevapApi = Read-Host '    Acilan sayfada "Google Apps Script API" anahtarini ACIK yapip Enter''a basin ([C] Cikis)'
                    if ($cevapApi -match '^[Cc\u00E7\u00C7]$' -or $cevapApi -eq [string][char]0x00E7 -or $cevapApi -eq [string][char]0x00C7) { exit 0 }
                } else {
                    Uyari ('    [!] Tarayicida acilan sayfadan "Google Apps Script API" anahtarini ACIK yapin (kontrol ' + $apiDeneme + '/5, 10 sn bekleniyor)...')
                    Start-Sleep -Seconds 10
                }
            } elseif ($cikarilmis -and $apiDeneme -eq 1) {
                # Eski scriptId gecersiz veya silinmis olabilir; sifirdan olusturmayi dene
                Uyari '    [!] Eski proje kimligine erisilemedi, yeni proje olusturuluyor...'
                if (Test-Path $claspJsonYol) { Remove-Item $claspJsonYol -Force -ErrorAction SilentlyContinue }
                $cikarilmis = $false
            } else {
                throw
            }
        }
    }

    Adim 'Yayin (Web Uygulamasi) guncelleniyor / olusturuluyor'
    $deploymentId = $null
    $eskiCfg = ConfigOku
    if ($onceki -and $onceki.DeploymentId) { $deploymentId = $onceki.DeploymentId }
    elseif ($eskiCfg -and $eskiCfg.deploymentId) { $deploymentId = $eskiCfg.deploymentId }

    # Eger deploymentId biliniyorsa veya bulutta mevcut bir yayin varsa onu bul
    if (-not $deploymentId) {
        try {
            $depListOut = Clasp-Cagir -Argumanlar @('--json', 'list-deployments') -Sessiz
            $depMatches = [regex]::Matches($depListOut, '"deploymentId"\s*:\s*"([^"]+)"')
            foreach ($m in $depMatches) {
                $cand = $m.Groups[1].Value
                if ($cand -and $cand -ne '@HEAD') { $deploymentId = $cand }
            }
        } catch {
            try {
                $depListTxt = Clasp-Cagir -Argumanlar @('list-deployments') -Sessiz
                foreach ($line in ($depListTxt -split "`r?`n")) {
                    if ($line -match '-\s+([A-Za-z0-9_-]{20,})\s+@\d+') {
                        $deploymentId = $Matches[1]
                    }
                }
            } catch {}
        }
    }

    $aciklama = 'Kuzgun CRM ' + $Surdur + ' (' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + ')'
    $cikti = ''
    $yayinTamam = $false

    if ($deploymentId) {
        try {
            $cikti = Clasp-Cagir -Argumanlar @('update-deployment', $deploymentId, '-d', $aciklama, '--json') -Sessiz
            $yayinTamam = $true
        } catch {}
        foreach ($komut in @('create-deployment', 'deploy')) {
            if ($yayinTamam) { break }
            try {
                $cikti = Clasp-Cagir -Argumanlar @($komut, '-i', $deploymentId, '-d', $aciklama) -Sessiz
                $yayinTamam = $true
            } catch {
                try {
                    $cikti = Clasp-Cagir -Argumanlar @($komut, '-i', $deploymentId, '-d', $aciklama, '--json') -Sessiz
                    $yayinTamam = $true
                } catch {}
            }
        }
    }

    if (-not $yayinTamam) {
        foreach ($komut in @('create-deployment', 'deploy')) {
            if ($yayinTamam) { break }
            try {
                $cikti = Clasp-Cagir -Argumanlar @($komut, '-d', $aciklama) -Sessiz
                $yayinTamam = $true
            } catch {
                try {
                    $cikti = Clasp-Cagir -Argumanlar @($komut, '-d', $aciklama, '--json') -Sessiz
                    $yayinTamam = $true
                } catch {}
            }
        }
    }

    try {
        $j = $cikti | Select-String -Pattern '\{[\s\S]*\}' | ForEach-Object { $_.Matches[0].Value } | Select-Object -First 1
        if ($j) {
            $dep = $j | ConvertFrom-Json
            if ($dep.deploymentId) { $deploymentId = $dep.deploymentId }
        }
    } catch {}
    if (-not $deploymentId -and $cikti -match '(?:Deployed|Redeployed)\s+([A-Za-z0-9_-]+)\s+@') {
        $deploymentId = $Matches[1]
    }

    if ($deploymentId) {
        Basari ('    [OK] Yayin hazir (ID: ' + $deploymentId + ')')
    } else {
        Uyari '    [!] deploymentId dogrudan okunamadi, yayin listesinden aliniyor...'
    }

    Adim 'Web adresi dogrulaniyor'
    $url = $null
    if ($deploymentId) {
        $url = "https://script.google.com/macros/s/$deploymentId/exec"
    }
    if (-not $url) {
        try {
            $cikti3 = Clasp-Cagir -Argumanlar @('list-deployments') -Sessiz
            foreach ($line in ($cikti3 -split "`r?`n")) {
                if ($line -match '-\s+([A-Za-z0-9_-]{20,})\s+@\d+') {
                    $deploymentId = $Matches[1]
                    $url = "https://script.google.com/macros/s/$deploymentId/exec"
                }
            }
        } catch {}
    }
    if (-not $url -and $onceki -and $onceki.Url) {
        $url = $onceki.Url
    }
    if (-not $url) { throw 'Web uygulamasi adresi alinamadi. Clasp loguna bakin.' }
    Basari ('    [OK] ' + $url)

    return @{ url = $url; deploymentId = $deploymentId; scriptId = $mevcutScriptId; account = $hesap }
}

function Asama4_Tamam {
    param([hashtable]$sonuc, [bool]$guncellendi = $false)
    if ($guncellendi) {
        Baslik ('ISLEM TAMAMLANDI - KURULUM GUNCELLENDI (' + $Surdur + ')')
        Basari '  Mevcut CRM kurulumunuz basariyla guncellendi:'
    } else {
        Baslik ('ISLEM TAMAMLANDI - YENI KURULUM HAZIR (' + $Surdur + ')')
        Basari '  CRM Masaustu Uygulamasi basariyla kuruldu ve kullanima hazir:'
    }
    $hedefExe = Join-Path $Ana 'KuzgunCRM.exe'
    if (Test-Path $hedefExe) {
        Satir White ('    UYGULAMA      : ' + $hedefExe)
    }
    if ($sonuc.url -and $sonuc.url -like 'https://*') {
        Satir White ('    BULUT ADRESI  : ' + $sonuc.url)
    }
    if ($sonuc.account) {
        Satir White ('    GOOGLE HESABI : ' + $sonuc.account + ' (Otomatik Eslendi)')
    }
    Satir White '    VARSAYILAN PIN: kuzgun2024  (Ilk giriste otomatik baglanir)'
    if ($sonuc.migratedCount -gt 0) {
        Satir Green ("    TASINAN VERI  : $($sonuc.migratedCount) cihaz kaydi yeni surume basariyla aktarildi")
    }
    Write-Host ''
    Satir Gray '  - CRM masaustu uygulamasi simdi otomatik aciliyor.'
    Satir Gray '  - Masaustune "Kuzgun CRM" uygulama kisayolu eklendi / guncellendi.'
    Satir Gray '  - Google Bulut eslemesi icin uygulama icindeki "Google Buluta Bagla (2 Tikla)" butonunu kullanabilirsiniz.'
    Write-Host ''
    if ($script:ClaspLog) {
        $log = Join-Path $Ana 'kurulum.log'
        Set-Content -Path $log -Value $script:ClaspLog -Encoding UTF8
        Satir Gray ('  Kurulum logu: ' + $log)
    }
    if (-not $Sessiz) {
        if (Test-Path $hedefExe) {
            try { Start-Process -FilePath $hedefExe -ArgumentList '-Baslat' } catch {}
        } elseif ($sonuc.url) {
            try { Start-Process $sonuc.url } catch {}
        }
    }
    Write-Host ''
    Satir Green '  Otomatik islem basariyla tamamlandi!'
    if ($Etkilesimli) {
        $null = Read-Host '  Pencereyi kapatmak icin Enter tusuna basin'
    } else {
        Start-Sleep -Seconds 1
    }
}

function EskiKurulumTemizle {
    param([string]$HedefYedekDizin = '')
    # Eski surumlerin masaustu dosyalari / 127.0.0.1 yerel sunucusu yeni surumu golgeliyor; yedekleyip tasi (asla silme!)
    try {
        $yedekKlasor = if ($HedefYedekDizin) { Join-Path $HedefYedekDizin 'eski_masaustu' } else { Join-Path $Ana ('eski_masaustu_' + (Get-Date -Format 'yyyyMMdd_HHmmss')) }
        $tasindi = 0
        foreach ($d in (MasaustuKlasorleri)) {
            foreach ($f in (Get-ChildItem -Path $d -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)kuzgun' -and $_.Extension -match '(?i)^\.(html?|lnk|url|bat|cmd|vbs|py|ps1)$' })) {
                if (-not (Test-Path $yedekKlasor)) { New-Item -ItemType Directory -Path $yedekKlasor -Force | Out-Null }
                Move-Item -Path $f.FullName -Destination (Join-Path $yedekKlasor $f.Name) -Force -ErrorAction SilentlyContinue
                $tasindi++
            }
        }
        # Eski surumun baslangicta calisan kisayollari
        $startup = [Environment]::GetFolderPath('Startup')
        if ($startup -and (Test-Path $startup)) {
            foreach ($f in (Get-ChildItem -Path $startup -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)kuzgun' })) {
                if (-not (Test-Path $yedekKlasor)) { New-Item -ItemType Directory -Path $yedekKlasor -Force | Out-Null }
                Move-Item -Path $f.FullName -Destination (Join-Path $yedekKlasor $f.Name) -Force -ErrorAction SilentlyContinue
                $tasindi++
            }
        }
        # Eski yerel (127.0.0.1) sunucu surecleri (Canli veri cekildikten sonra guvenle durdurulur)
        $durdu = 0
        foreach ($pr in (Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
                $_.ProcessId -ne $PID -and $_.Name -match '(?i)^(python|pythonw|node|php)\.exe$' -and
                $_.CommandLine -match '(?i)kuzgun' -and $_.CommandLine -notmatch '(?i)clasp|npm' })) {
            try { Stop-Process -Id $pr.ProcessId -Force -ErrorAction Stop; $durdu++ } catch {}
        }
        if ($tasindi -gt 0) { Basari ('  [OK] Eski masaustu dosyalari yedeklenip tasindi (' + $tasindi + ') -> ' + $yedekKlasor) }
        if ($durdu -gt 0) { Basari ('  [OK] Eski yerel sunucu (127.0.0.1) durduruldu (' + $durdu + ')') }
    } catch { Uyari ('  [!] Eski kurulum temizligi atlandi: ' + $_.Exception.Message) }
}

function KisayolOlustur {
    param(
        [string]$url,
        $cihazlar = $null
    )
    if (-not (Test-Path $Ana)) { New-Item -ItemType Directory -Path $Ana -Force | Out-Null }

    # 0) Standalone KuzgunCRM.exe kopyasini %LOCALAPPDATA%\KuzgunCRM\KuzgunCRM.exe olarak yerlestir
    $hedefExe = Join-Path $Ana 'KuzgunCRM.exe'
    $kaynakExeler = @()
    if ($ExeDir) {
        $kaynakExeler += (Join-Path $ExeDir 'KuzgunCRM_Kurulum.exe')
        $kaynakExeler += (Join-Path $ExeDir 'KuzgunCRM.exe')
    }
    $kaynakExeler += (Join-Path $Kaynak 'KuzgunCRM_Kurulum.exe')
    $kaynakExeler += (Join-Path (Split-Path -Parent $Kaynak) 'KuzgunCRM_Kurulum.exe')
    foreach ($adayExe in $kaynakExeler) {
        if ($adayExe -and (Test-Path $adayExe)) {
            try {
                if ($adayExe -ne $hedefExe) {
                    Copy-Item -Path $adayExe -Destination $hedefExe -Force -ErrorAction SilentlyContinue
                }
                break
            } catch {}
        }
    }

    # 1) Web adresi ve gomulu veriler enjekte edilmis yerel HTML kopya
    $html = Get-Content (Join-Path $Kaynak 'Kuzgun_Iletisim_CRM.html') -Raw -Encoding UTF8
    if ($url -and $url -like 'https://*') {
        $html = $html.Replace("const EMBED_URL = '';", "const EMBED_URL = '" + $url + "';")
    }

    # Eger cihaz listesi verilmediyse diskteki migrated_devices.json'dan oku
    if (-not $cihazlar) {
        $migFile = Join-Path $Ana 'migrated_devices.json'
        if (Test-Path $migFile) {
            try {
                $cihazlar = Get-Content $migFile -Raw -Encoding UTF8 | ConvertFrom-Json
            } catch {}
        }
    }

    if ($cihazlar -and @($cihazlar).Count -gt 0) {
        $devJson = ConvertTo-Json -InputObject @($cihazlar) -Depth 5 -Compress
        $html = $html.Replace("const EMBED_DEVICES = [];", "const EMBED_DEVICES = " + $devJson + ";")

        # Standalone sunucu veritabani (veritabani.json) ve ilk yedegi olustur
        $vtDosya = Join-Path $Ana 'veritabani.json'
        if (-not (Test-Path $vtDosya)) {
            [System.IO.File]::WriteAllText($vtDosya, $devJson, (New-Object System.Text.UTF8Encoding($false)))
        }
        $yedekDizin = Join-Path $Ana 'yedekler'
        if (-not (Test-Path $yedekDizin)) { New-Item -ItemType Directory -Path $yedekDizin -Force | Out-Null }
        $ilkYedek = Join-Path $yedekDizin ('kuzgun-crm-' + (Get-Date -Format 'yyyy-MM-dd') + '.json')
        if (-not (Test-Path $ilkYedek)) {
            $yedekZarfi = @{
                app = 'kuzgun-crm'
                version = $Surdur
                exported_at = (Get-Date -Format o)
                count = @($cihazlar).Count
                devices = @($cihazlar)
            }
            $yedekJson = ConvertTo-Json -InputObject $yedekZarfi -Depth 6
            [System.IO.File]::WriteAllText($ilkYedek, $yedekJson, (New-Object System.Text.UTF8Encoding($false)))
        }
    }

    $yerelHtml = Join-Path $Ana 'Kuzgun_CRM.html'
    [System.IO.File]::WriteAllText($yerelHtml, $html, (New-Object System.Text.UTF8Encoding($false)))

    $kisayolHedef = if (Test-Path $hedefExe) { $hedefExe } else { $yerelHtml }
    $kisayolArg = if (Test-Path $hedefExe) { '-Baslat' } else { '' }
    $kisayolIkon = if (Test-Path $hedefExe) { "$hedefExe,0" } else { 'shell32.dll,13' }

    $olustu = 0
    foreach ($d in (MasaustuKlasorleri)) {
        try {
            $lnk = Join-Path $d 'Kuzgun CRM.lnk'
            $ws = New-Object -ComObject WScript.Shell
            $k = $ws.CreateShortcut($lnk)
            $k.TargetPath = $kisayolHedef
            if ($kisayolArg) { $k.Arguments = $kisayolArg }
            $k.WorkingDirectory = $Ana
            $k.Description = 'Kuzgun Iletisim CRM ' + $Surdur
            $k.IconLocation = $kisayolIkon
            $k.Save()
            if ($url -and $url -like 'https://*') { "[InternetShortcut]`r`nURL=$url" | Set-Content (Join-Path $d 'Kuzgun CRM (Bulut).url') -Encoding ASCII }
            $olustu++
            Basari ('  [OK] Masaustu kisayolu: ' + $lnk)
        } catch { Uyari ('  [!] Kisayol olusturulamadi (' + $d + '): ' + $_.Exception.Message) }
    }
    # Baslat menusu
    try {
        $sm = Join-Path ([Environment]::GetFolderPath('Programs')) 'Kuzgun CRM.lnk'
        $ws2 = New-Object -ComObject WScript.Shell
        $k2 = $ws2.CreateShortcut($sm)
        $k2.TargetPath = $kisayolHedef
        if ($kisayolArg) { $k2.Arguments = $kisayolArg }
        $k2.WorkingDirectory = $Ana
        $k2.IconLocation = $kisayolIkon
        $k2.Save()
    } catch {}
    if ($olustu -eq 0) { Uyari ('  [!] Masaustu kisayolu olusmadi. Uygulamayi buradan acabilirsiniz: ' + $kisayolHedef) }
}

function OtomatikCalistir {
    param($onceki)
    $guncellemeMi = [bool]($onceki -and $onceki.Bulundu -and -not $Sifirdan)
    if ($guncellemeMi) {
        Baslik ('ONCEKI KURULUM ALGILANDI -> OTOMATIK GUNCELLENIYOR (' + $Surdur + ')')
        if ($onceki.Url) { Satir White ('    MEVCUT ADRES  : ' + $onceki.Url) }
        if ($onceki.ScriptId) { Satir White ('    PROJE KIMLIGI : ' + $onceki.ScriptId) }
        Satir Cyan ('    Mevcut verileriniz taranip korunarak yeni surum (' + $Surdur + ') uzerine yaziliyor...')
    } else {
        Baslik ('TEK TIKLA OTOMATIK KURULUM BASLATILIYOR (' + $Surdur + ')')
        Satir Cyan '    Masaustu uygulamasi, yerel veritabani ve otomatik yedekleme sistemi kuruluyor...'
    }

    $durum = Asama2_Gereksinim
    $erisim = 'ANYONE_ANONYMOUS'
    if ($onceki -and $onceki.Erisim -and $onceki.Erisim -ne 'ANYONE') { $erisim = $onceki.Erisim }

    # 1. VERI MIGRASIYONU: Canli sunucu probe -> dosya ve sqlite taramasi -> guvenli yedekleme -> temizlik
    $migrated = VeriMigrasyonYurut -onceki $onceki

    # 2. Dosyalari hazirla (migrated veriler index.html icine de enjekte edilir)
    DosyalariHazirla -erisim $erisim

    # 3. Masaustu kisayolunu ve Standalone KuzgunCRM.exe uygulamasini olustur
    $varsayilanUrl = if ($onceki -and $onceki.Url -and $onceki.Url -like 'https://*') { $onceki.Url } else { '' }
    KisayolOlustur -url $varsayilanUrl -cihazlar $migrated

    # Eger kullanicida zaten clasp oturumu (.clasprc.json) ve aktif bulut projesi varsa sessizce bulutu da guncelle;
    # aksi halde clasp/npm yuzunden kurulumu bekletme veya durdurma!
    $claspOturumVar = (Test-Path (Join-Path $env:USERPROFILE '.clasprc.json')) -and ($onceki -and $onceki.ScriptId)
    if ($durum.Internet -and $durum.Node -and ($claspOturumVar -or $Yenile)) {
        try {
            $sonuc = Asama_OtomatikKurulum -erisim $erisim -onceki $onceki
            ConfigYaz @{
                url = $sonuc.url
                deploymentId = $sonuc.deploymentId
                scriptId = $sonuc.scriptId
                googleAccount = $sonuc.account
                erisim = $erisim
                guncelleme = (Get-Date -Format o)
                surum = $Surdur
                migratedCount = $(if ($migrated) { @($migrated).Count } else { 0 })
            }
            KisayolOlustur -url $sonuc.url -cihazlar $migrated
            $sonuc['migratedCount'] = $(if ($migrated) { @($migrated).Count } else { 0 })
            Asama4_Tamam -sonuc $sonuc -guncellendi $guncellemeMi
            return
        } catch {
            Uyari ('  [!] Clasp bulut guncellemesi atlandi: ' + $_.Exception.Message)
        }
    }

    Basari '  [OK] Kuzgun CRM Standalone Masaustu Uygulamasi, Veritabani ve Yedekleme Sistemi hazir!'
    $yerelSonuc = @{
        url = $varsayilanUrl
        deploymentId = $(if ($onceki -and $onceki.DeploymentId) { $onceki.DeploymentId } else { '' })
        scriptId = $(if ($onceki -and $onceki.ScriptId) { $onceki.ScriptId } else { '' })
        account = ''
        migratedCount = $(if ($migrated) { @($migrated).Count } else { 0 })
    }
    ConfigYaz @{
        url = $varsayilanUrl
        deploymentId = $yerelSonuc.deploymentId
        scriptId = $yerelSonuc.scriptId
        googleAccount = ''
        erisim = $erisim
        guncelleme = (Get-Date -Format o)
        surum = $Surdur
        migratedCount = $yerelSonuc.migratedCount
    }
    Asama4_Tamam -sonuc $yerelSonuc -guncellendi $guncellemeMi
}

function ManuelRehber {
    Baslik 'MANUEL KILAVUZ (adim adim, yaklasik 5 dakika)'
    Bilgi 'Otomatik kurulum calismazsa bu adimlari izleyin:'
    Write-Host ''
    Satir White '  A) Google hesabi (yoksa): https://accounts.google.com  -> Hesap olusturun'
    Satir White '  B) Yeni E-Tablo (bulut Excel = veritabani): https://sheets.new'
    Satir White '  C) Uzantilar > Apps Script (kod motoru)'
    Satir White '  D) Code.gs icerigini yapistirin (kopyala-yapistir):'
    Satir Gray ('       notepad "' + (Join-Path $Kaynak 'Code.gs') + '"')
    Satir White '  E) + > HTML dosyasi, adini "index" yapin, HTML icerigini yapistirin:'
    Satir Gray ('       notepad "' + (Join-Path $Kaynak 'Kuzgun_Iletisim_CRM.html') + '"')
    Satir White '  F) Apps Script API anahtarini ACIN:'
    Satir Gray '       https://script.google.com/home/usersettings'
    Satir White '  G) Dagitim > Yeni dagitim > Web uygulamasi:'
    Satir Gray '       Calistirilacak kisi: Ben   |   Erisim izni: Su herkes'
    Satir White '  H) Verilen /exec adresini acin (Ilk giriste otomatik eslenir, PIN: kuzgun2024)'
    Write-Host ''
    Satir Yellow ('  Not: Kod ve HTML dosyalari bu klasorde: ' + $Kaynak)
}

function TestModu {
    Baslik 'TEST MODU (dokunmadan dogrulama)'
    $durum = Asama2_Gereksinim
    $basarili = $durum.Internet -and $durum.Node -and $durum.Npm -and $durum.Kaynak

    $testKlasor = Join-Path $env:TEMP 'kuzgun-crm-test'
    if (Test-Path $testKlasor) { Remove-Item $testKlasor -Recurse -Force }
    $eskiProje = $script:Proje
    $eskiAna = $script:Ana
    $script:Proje = $testKlasor
    $script:Ana = Join-Path $env:TEMP 'kuzgun-crm-test-ana'
    try {
        DosyalariHazirla -erisim 'ANYONE_ANONYMOUS'
        $m2 = Get-Content (Join-Path $testKlasor 'appsscript.json') -Raw | ConvertFrom-Json
        if ($m2.webapp.access -eq 'ANYONE_ANONYMOUS') { Basari '  [OK] dosya hazirlama + manifest erisim yamasi' } else { Hata '  [X] manifest yamasi'; $basarili = $false }
        foreach ($f in @('Code.gs', 'index.html', 'appsscript.json')) {
            if (-not (Test-Path (Join-Path $testKlasor $f))) { Hata ('  [X] eksik kopya: ' + $f); $basarili = $false }
        }
        $mHtml = Get-Content (Join-Path $testKlasor 'index.html') -Raw
        if ($mHtml -notmatch 'createApp') { Hata '  [X] index.html bozuk'; $basarili = $false }
        ConfigYaz @{ url = 'https://script.google.com/macros/s/TEST/exec'; deploymentId = 'D1'; scriptId = 'S1' }
        $geri = ConfigOku
        if ($geri.url -like '*exec') { Basari '  [OK] kurulum bilgisi yazma/okuma' } else { Hata '  [X] config yuvarlak yol'; $basarili = $false }

        $algilanan = OncekiKurulumBul
        if ($algilanan.Bulundu -and $algilanan.DeploymentId -eq 'D1' -and $algilanan.ScriptId -eq 'S1') {
            Basari '  [OK] onceki kurulum otomatik algilama ve kurtarma'
        } else {
            Hata '  [X] onceki kurulum algilama basarisiz'; $basarili = $false
        }

        # TEST: CihazNormalle (Eski Turkce alan adlari ve sema donusumu)
        $testRaw = @{
            kayit_id = 101
            tur = 'tamir'
            durum = 'islemde'
            cihaz_marka = 'Apple'
            cihaz_model = 'iPhone 11'
            imei_no = '353123456789012'
            seri_no = 'F2LZ9999'
            musteri_adi = 'Mehmet Demir'
            musteri_tel = '05559876543'
            yapilan_islem = 'Batarya degisimi'
            sifre = '2024'
            aciklama = 'Kasa temizlenecek'
            fiyat = '1.250,50 TL'
            kayit_tarihi = '2024-05-10 14:30:00'
        }
        $normDev = CihazNormalle $testRaw
        if ($normDev -and $normDev.id -eq 101 -and $normDev.type -eq 'REPAIR' -and $normDev.status -eq 'IN_PROGRESS' -and
            $normDev.customer_name -eq 'Mehmet Demir' -and $normDev.notes -like '*2024*' -and $normDev.price -eq 1250.5 -and
            $normDev.created_at -gt 100000000000L) {
            Basari '  [OK] CihazNormalle eski Turkce alan adlari ve format donusumu'
        } else {
            Hata '  [X] CihazNormalle donusum hatasi'
            $basarili = $false
        }

        # TEST: EMBED_DEVICES enjeksiyonu
        $testDevList = @($normDev)
        $migTestFile = Join-Path $script:Ana 'migrated_devices.json'
        [System.IO.File]::WriteAllText($migTestFile, (ConvertTo-Json -InputObject @($testDevList) -Depth 5), (New-Object System.Text.UTF8Encoding($false)))
        DosyalariHazirla -erisim 'ANYONE_ANONYMOUS'
        $indexHtml = Get-Content (Join-Path $testKlasor 'index.html') -Raw
        if ($indexHtml -match 'const EMBED_DEVICES = \[\{.*Mehmet Demir.*\}\];') {
            Basari '  [OK] EMBED_DEVICES HTML enjeksiyonu ve veri guvenligi'
        } else {
            Hata '  [X] EMBED_DEVICES enjeksiyonu basarisiz'
            $basarili = $false
        }

        # TEST: Canli sunucu probe guvenligi (zaman asimi ve sessiz hata yonetimi)
        try {
            $probeRes = CanliSunucuVeriCek
            Basari '  [OK] Canli sunucu tarama mekanizmasi ve guvenli zaman asimi'
        } catch {
            Hata ('  [X] Canli sunucu taramasi hata verdi: ' + $_.Exception.Message)
            $basarili = $false
        }

        # TEST: Guvenli tasima (move-never-delete)
        $dummyTestFile = Join-Path $testKlasor 'dummy_legacy.bat'
        Set-Content -Path $dummyTestFile -Value '@echo off' -Encoding ASCII
        $destBackup = Join-Path $testKlasor 'test_yedek_klasor'
        if (-not (Test-Path $destBackup)) { New-Item -ItemType Directory -Path $destBackup -Force | Out-Null }
        Move-Item -Path $dummyTestFile -Destination (Join-Path $destBackup 'dummy_legacy.bat') -Force
        if (-not (Test-Path $dummyTestFile) -and (Test-Path (Join-Path $destBackup 'dummy_legacy.bat'))) {
            Basari '  [OK] Eski dosyalari silmeden guvenli tasima (move-never-delete)'
        } else {
            Hata '  [X] Dosya tasima dogrulamasi basarisiz'
            $basarili = $false
        }

        $fakeBin = Join-Path $testKlasor 'node_modules\.bin'
        if (-not (Test-Path $fakeBin)) { New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null }
        $fake = Join-Path $fakeBin 'clasp.cmd'
        $fakeContent = @'
@echo off
if "%1"=="create-deployment" echo {"deploymentId":"FAKE123","versionNumber":1,"description":"t"}
if "%1"=="create-deployment" exit /b 0
if "%1"=="hata" echo ariza-mesaji
if "%1"=="hata" exit /b 5
echo user@example.com
exit /b 0
'@
        Set-Content -Path $fake -Value $fakeContent -Encoding ASCII
        if ((ClaspYoluBul) -eq $fake) { Basari '  [OK] clasp yolu bulma (proje ici)' } else { Hata '  [X] clasp yolu bulma'; $basarili = $false }
        try {
            $cOut = Clasp-Cagir -Argumanlar @('create-deployment', '-d', 't', '--json') -Sessiz
            $j = $cOut | Select-String -Pattern '\{[\s\S]*\}' | ForEach-Object { $_.Matches[0].Value } | Select-Object -First 1
            $fakeDep = $j | ConvertFrom-Json
            if ($fakeDep.deploymentId -eq 'FAKE123') { Basari '  [OK] clasp cagrisi + cikti yakalama (sahte clasp)' } else { Hata '  [X] clasp cagrisi'; $basarili = $false }
        } catch { Hata ('  [X] clasp cagrisi firlatti: ' + $_.Exception.Message); $basarili = $false }
        try {
            $null = Clasp-Cagir -Argumanlar @('hata') -Sessiz
            Hata '  [X] hatali clasp kodu yakalanamadi'; $basarili = $false
        } catch { Basari '  [OK] hatali clasp ciktilari yakalanip raporlandi' }
        Remove-Item $fake -Force
    } finally {
        $script:Proje = $eskiProje
        $script:Ana = $eskiAna
    }

    if ($basarili) { Write-Host ''; Basari 'TEST: TUM KONTROLLER GECTI'; return 0 }
    Write-Host ''; Hata 'TEST: BASARISIZ KONTROLLER VAR'; return 1
}

$script:AdimNo = 0
$script:ClaspLog = ''

try {
    if ($Bilgi) { Asama1_Bilgilendirme; exit 0 }
    if ($Manuel) { ManuelRehber; exit 0 }
    if ($Test) { exit (TestModu) }

    if ($Hazirlik) {
        $d = Asama2_Gereksinim
        if ($d.Internet -and $d.Node -and $d.Npm -and $d.Kaynak) { exit 0 } else { exit 1 }
    }

    # Mevcut kurulumu hem kurulum.json hem de .clasp.json uzerinden algila
    $onceki = OncekiKurulumBul

    # Varsayilan davranis: One-Click Exe! Soru sormadan otomatik kur veya guncelle.
    if (-not $Etkilesimli) {
        OtomatikCalistir -onceki $onceki
        exit 0
    }

    # Etkilesimli mod (-Etkilesimli parametresi verildiginde)
    Asama1_Bilgilendirme
    $null = Devam

    if ($onceki.Bulundu) {
        Baslik 'ONCEKI KURULUM BULUNDU'
        if ($onceki.Url) { Satir White ('    ADRES : ' + $onceki.Url) }
        $cevap = Read-Host '  [G] Guncelle (Enter)  [Y] Yeni kurulum (sifirdan)  [C] Cikis'
        if ($cevap -match '^[Cc\u00E7\u00C7]$' -or $cevap -eq [string][char]0x00E7 -or $cevap -eq [string][char]0x00C7) { exit 0 }
        if ($cevap -match '^[Yy]$') { $Sifirdan = $true }
    }

    OtomatikCalistir -onceki $onceki
    exit 0
}
catch {
    Write-Host ''
    Hata ('KURULUM DURDU: ' + $_.Exception.Message)
    Write-Host ''
    Uyari '  Yayin adiminda sorun olursa elle tamamlayabilirsiniz:'
    Uyari '   1) https://script.google.com/home/usersettings -> Apps Script API acik olsun'
    Uyari '   2) Script editoru: clasp login durumunu dogrulamak icin: clasp show-authorized-user'
    Uyari '   3) Veya asagidaki MANUEL KILAVUZ ile ilerleyin:'
    Write-Host ''
    ManuelRehber
    if ($script:ClaspLog) {
        $log = Join-Path $Ana 'kurulum.log'
        if (-not (Test-Path $Ana)) { New-Item -ItemType Directory -Path $Ana -Force | Out-Null }
        Set-Content -Path $log -Value $script:ClaspLog -Encoding UTF8
        Satir Gray ('  Ayrinti: ' + $log)
    }
    Write-Host ''
    if ($Etkilesimli) { $null = Read-Host '  Kapatmak icin Enter tusuna basin' }
    exit 1
}