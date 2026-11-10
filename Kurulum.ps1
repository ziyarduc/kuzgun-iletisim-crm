#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Bilgi,
    [switch]$Hazirlik,
    [switch]$Manuel,
    [switch]$Yenile,
    [switch]$Sifirdan,
    [switch]$Etkilesimli,
    [switch]$Test
)

$ErrorActionPreference = 'Stop'
$Kaynak = $PSScriptRoot
$Ana = Join-Path $env:LOCALAPPDATA 'KuzgunCRM'
$Proje = Join-Path $Ana 'proje'
$Surdur = 'v2.2.0'
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
    if ($cevap -match '^[CcçÇ]$') {
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
        try {
            & winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Null
            PathYenile
            if (KomutVarMi 'node') {
                Basari '  [OK] Node.js winget ile otomatik kuruldu!'
                return $true
            }
        } catch {}
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
        $nodeS = (& node -v 2>&1 | Out-String).Trim()
        $major = 0; [void][int]::TryParse(($nodeS -replace '^v(\d+)\..*$', '$1'), [ref]$major)
        if ($major -ge 16) { $nodeOk = $true; Basari ("  [OK] Node.js: " + $nodeS) }
        else { Uyari ("  [!] Node.js eski: " + $nodeS + ' (16+ gerekli)') }
    } else { Uyari '  [!] Node.js yok (otomatik kurulacak)' }

    $npmOk = KomutVarMi 'npm'
    if ($npmOk) { Basari ('  [OK] npm: ' + (& npm -v 2>&1 | Out-String).Trim()) } else { Uyari '  [!] npm yok' }

    $kaynakOk = $true
    foreach ($f in @('Code.gs', 'Kuzgun_Iletisim_CRM.html', 'appsscript.json')) {
        if (Test-Path (Join-Path $Kaynak $f)) { Basari ('  [OK] Kaynak dosya: ' + $f) }
        else { Hata ('  [X] Kaynak eksik: ' + $f); $kaynakOk = $false }
    }

    $yerelClasp = Join-Path (Join-Path $Proje 'node_modules\.bin') 'clasp.cmd'
    if (KomutVarMi 'clasp') { Basari '  [OK] clasp: sistemde kurulu' }
    elseif (Test-Path $yerelClasp) { Basari '  [OK] clasp: onceki kurulumdan (proje ici)' }
    else { Uyari '  [ ] clasp: otomatik kurulacak (proje klasorune)' }

    return [pscustomobject]@{ Internet = $net; Node = $nodeOk; Npm = $npmOk; Kaynak = $kaynakOk }
}

function DosyalariHazirla {
    param([string]$erisim)
    if (-not (Test-Path $Proje)) { New-Item -ItemType Directory -Path $Proje -Force | Out-Null }
    Copy-Item (Join-Path $Kaynak 'Code.gs') (Join-Path $Proje 'Code.gs') -Force
    Copy-Item (Join-Path $Kaynak 'Kuzgun_Iletisim_CRM.html') (Join-Path $Proje 'index.html') -Force
    Copy-Item (Join-Path $Kaynak 'appsscript.json') (Join-Path $Proje 'appsscript.json') -Force
    $m = Get-Content (Join-Path $Proje 'appsscript.json') -Raw | ConvertFrom-Json
    $m.webapp.access = $erisim
    ConvertTo-Json -InputObject $m -Depth 10 | Set-Content (Join-Path $Proje 'appsscript.json') -Encoding UTF8
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
    if ($cfg -or $scriptId) {
        $erisim = 'ANYONE'
        if ($cfg -and $cfg.erisim) { $erisim = $cfg.erisim }
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
        }
    }
    return [pscustomobject]@{ Bulundu = $false }
}

function ClaspYoluBul {
    $yerel = Join-Path (Join-Path $Proje 'node_modules\.bin') 'clasp.cmd'
    if (Test-Path $yerel) { return $yerel }
    if (KomutVarMi 'clasp') { return 'clasp' }
    return $null
}
function Clasp-Cagir {
    param([string[]]$Argumanlar, [string]$Is, [switch]$Sessiz)
    $yol = ClaspYoluBul
    if (-not $yol) { throw 'clasp bulunamadi' }
    if (-not $Sessiz) { Write-Host ('    > clasp ' + ($Argumanlar -join ' ')) -ForegroundColor DarkGray }
    Push-Location $Proje
    try {
        $cikti = & $yol @Argumanlar 2>&1 | Out-String
        $kod = $LASTEXITCODE
    } finally {
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
        Push-Location $Proje
        try {
            & npm i @google/clasp --no-fund --no-audit 2>&1 | Select-Object -Last 3 | ForEach-Object { Write-Host ('    ' + $_) -ForegroundColor DarkGray }
        } finally {
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
        } elseif ($out -match '@') {
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
                    @{ scriptId = $mevcutScriptId; rootDir = '.' } | ConvertTo-Json | Set-Content $claspJsonYol -Encoding UTF8
                    $cikarilmis = $true
                    Basari ('    [OK] Buluttaki mevcut Kuzgun CRM projesi bulundu ve baglandi (ID: ' + $mevcutScriptId + ')')
                    break
                }
            }
        } catch {}
    }

    # Projeyi olustur veya kodu yukle (Apps Script API kapaliysa otomatik algilayip ac)
    for ($apiDeneme = 1; $apiDeneme -le 2; $apiDeneme++) {
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

            Adim 'Guncel kodlar buluta yukleniyor (push)'
            $null = Clasp-Cagir -Argumanlar @('push', '--force')
            Basari '    [OK] Code.gs + index.html + manifest basariyla yuklendi'
            break
        } catch {
            $hataMesaj = $_.Exception.Message
            if ($apiDeneme -eq 1 -and ($hataMesaj -match 'User has not enabled the Apps Script API' -or $hataMesaj -match 'script\.google\.com/home/usersettings' -or $hataMesaj -match 'API')) {
                Uyari '    [!] Google Apps Script API henuz acik degil. Ayar sayfasi aciliyor...'
                Start-Process 'https://script.google.com/home/usersettings'
                $cevapApi = Read-Host '    Acilan sayfada "Google Apps Script API" anahtarini ACIK yapip Enter''a basin ([C] Cikis)'
                if ($cevapApi -match '^[CcçÇ]$') { exit 0 }
                Start-Sleep -Seconds 2
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
            $depListOut = Clasp-Cagir -Argumanlar @('list-deployments', '--json') -Sessiz
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
        # Hem yeni clasp (create-deployment -i) hem eski clasp (deploy -i) dene
        foreach ($komut in @('create-deployment', 'deploy')) {
            if ($yayinTamam) { break }
            try {
                $cikti = Clasp-Cagir -Argumanlar @($komut, '-i', $deploymentId, '-d', $aciklama, '--json') -Sessiz
                $yayinTamam = $true
            } catch {
                try {
                    $cikti = Clasp-Cagir -Argumanlar @($komut, '-i', $deploymentId, '-d', $aciklama) -Sessiz
                    $yayinTamam = $true
                } catch {}
            }
        }
    }

    if (-not $yayinTamam) {
        foreach ($komut in @('create-deployment', 'deploy')) {
            if ($yayinTamam) { break }
            try {
                $cikti = Clasp-Cagir -Argumanlar @($komut, '-d', $aciklama, '--json') -Sessiz
                $yayinTamam = $true
            } catch {
                try {
                    $cikti = Clasp-Cagir -Argumanlar @($komut, '-d', $aciklama) -Sessiz
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
    if (-not $deploymentId -and $cikti -match 'Deployed\s+([A-Za-z0-9_-]+)\s+@') {
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
        Basari '  Mevcut CRM kurulumunuz basariyla guncellendi ve Google hesabinizla eslendi:'
    } else {
        Baslik ('ISLEM TAMAMLANDI - YENI KURULUM HAZIR (' + $Surdur + ')')
        Basari '  CRM buluta kuruldu ve Google hesabinizla eslendi:'
    }
    Satir White ('    ADRES         : ' + $sonuc.url)
    if ($sonuc.account) {
        Satir White ('    GOOGLE HESABI : ' + $sonuc.account + ' (Otomatik Eslendi)')
    }
    Satir White '    VARSAYILAN PIN: kuzgun2024  (Ilk giriste otomatik baglanir)'
    Write-Host ''
    Satir Gray '  - CRM simdi tarayicinizda otomatik aciliyor ve Google hesabinizla esleniyor.'
    Satir Gray '  - Masaustune "Kuzgun CRM" kisayolu eklendi / guncellendi (eski surum dosyalari yedeklenip kaldirildi).'
    Satir Gray '  - Tekrar guncellemek icin KuzgunCRM_Kurulum.exe dosyasina cift tiklamaniz yeterlidir.'
    Write-Host ''
    if ($script:ClaspLog) {
        $log = Join-Path $Ana 'kurulum.log'
        Set-Content -Path $log -Value $script:ClaspLog -Encoding UTF8
        Satir Gray ('  Kurulum logu: ' + $log)
    }
    try { Start-Process $sonuc.url } catch {}
    Write-Host ''
    Satir Green '  Otomatik islem basariyla tamamlandi! (3 saniye icinde kapaniyor...)'
    if ($Etkilesimli) {
        $null = Read-Host '  Pencereyi kapatmak icin Enter tusuna basin'
    } else {
        Start-Sleep -Seconds 3
    }
}

function MasaustuKlasorleri {
    $liste = New-Object System.Collections.ArrayList
    foreach ($d in @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:USERPROFILE 'Desktop'),
                     $(if ($env:OneDrive) { Join-Path $env:OneDrive 'Desktop' }),
                     $(if ($env:OneDriveConsumer) { Join-Path $env:OneDriveConsumer 'Desktop' }),
                     $(if ($env:OneDriveCommercial) { Join-Path $env:OneDriveCommercial 'Desktop' }))) {
        if ($d -and (Test-Path $d) -and -not $liste.Contains($d)) { [void]$liste.Add($d) }
    }
    return ,$liste
}

function EskiKurulumTemizle {
    # Eski surumlerin masaustu dosyalari / 127.0.0.1 yerel sunucusu yeni surumu golgeliyor; yedekleyip kaldir
    try {
        $yedekKlasor = Join-Path $Ana ('eski_masaustu_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
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
        # Eski yerel (127.0.0.1) sunucu surecleri
        $durdu = 0
        foreach ($pr in (Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
                $_.ProcessId -ne $PID -and $_.Name -match '(?i)^(python|pythonw|node|php)\.exe$' -and
                $_.CommandLine -match '(?i)kuzgun' -and $_.CommandLine -notmatch '(?i)clasp|npm' })) {
            try { Stop-Process -Id $pr.ProcessId -Force -ErrorAction Stop; $durdu++ } catch {}
        }
        if ($tasindi -gt 0) { Basari ('  [OK] Eski masaustu dosyalari yedeklenip kaldirildi (' + $tasindi + ') -> ' + $yedekKlasor) }
        if ($durdu -gt 0) { Basari ('  [OK] Eski yerel sunucu (127.0.0.1) durduruldu (' + $durdu + ')') }
    } catch { Uyari ('  [!] Eski kurulum temizligi atlandi: ' + $_.Exception.Message) }
}

function KisayolOlustur {
    param([string]$url)
    # 1) Web adresi gomulu yerel kopya (cift tiklayinca dogrudan buluta baglanir)
    $html = Get-Content (Join-Path $Kaynak 'Kuzgun_Iletisim_CRM.html') -Raw -Encoding UTF8
    if ($url) { $html = $html.Replace("const EMBED_URL = '';", "const EMBED_URL = '" + $url + "';") }
    $yerelHtml = Join-Path $Ana 'Kuzgun_CRM.html'
    if (-not (Test-Path $Ana)) { New-Item -ItemType Directory -Path $Ana -Force | Out-Null }
    [System.IO.File]::WriteAllText($yerelHtml, $html, (New-Object System.Text.UTF8Encoding($false)))

    $olustu = 0
    foreach ($d in (MasaustuKlasorleri)) {
        try {
            # Ana kisayol: .lnk (yerel dosya, her zaman guncel adres gomulu) - ikon ile
            $lnk = Join-Path $d 'Kuzgun CRM.lnk'
            $ws = New-Object -ComObject WScript.Shell
            $k = $ws.CreateShortcut($lnk)
            $k.TargetPath = $yerelHtml
            $k.WorkingDirectory = $Ana
            $k.Description = 'Kuzgun Iletisim CRM ' + $Surdur
            $k.IconLocation = 'shell32.dll,13'
            $k.Save()
            # Bulut adresini dogrudan acan ikinci kisayol
            if ($url) { "[InternetShortcut]`r`nURL=$url" | Set-Content (Join-Path $d 'Kuzgun CRM (Bulut).url') -Encoding ASCII }
            $olustu++
            Basari ('  [OK] Masaustu kisayolu: ' + $lnk)
        } catch { Uyari ('  [!] Kisayol olusturulamadi (' + $d + '): ' + $_.Exception.Message) }
    }
    # Baslat menusu
    try {
        $sm = Join-Path ([Environment]::GetFolderPath('Programs')) 'Kuzgun CRM.lnk'
        $ws2 = New-Object -ComObject WScript.Shell
        $k2 = $ws2.CreateShortcut($sm); $k2.TargetPath = $yerelHtml; $k2.WorkingDirectory = $Ana; $k2.IconLocation = 'shell32.dll,13'; $k2.Save()
    } catch {}
    if ($olustu -eq 0) { Uyari ('  [!] Masaustu kisayolu olusmadi. Dosyayi elle acabilirsiniz: ' + $yerelHtml) }
}

function OtomatikCalistir {
    param($onceki)
    $guncellemeMi = [bool]($onceki -and $onceki.Bulundu -and -not $Sifirdan)
    if ($guncellemeMi) {
        Baslik ('ONCEKI KURULUM ALGILANDI -> OTOMATIK GUNCELLENIYOR (' + $Surdur + ')')
        if ($onceki.Url) { Satir White ('    MEVCUT ADRES  : ' + $onceki.Url) }
        if ($onceki.ScriptId) { Satir White ('    PROJE KIMLIGI : ' + $onceki.ScriptId) }
        Satir Cyan '    Mevcut verileriniz korunarak yeni surum (v2.2.0) uzerine yaziliyor...'
    } else {
        Baslik ('TEK TIKLA OTOMATIK KURULUM BASLATILIYOR (' + $Surdur + ')')
        Satir Cyan '    Hicbir ek ayar gerektirmeden otomatik kurulum ve Google eslemesi yapiliyor...'
    }

    $durum = Asama2_Gereksinim
    if (-not $durum.Internet) {
        Hata '  Internet baglantisi yok! Lutfen internetinizi kontrol edip tekrar deneyin.'
        exit 1
    }
    if (-not $durum.Node) {
        $kuruldu = NodeOtomatikKur
        if (-not $kuruldu -and -not (KomutVarMi 'node')) {
            Uyari '  Node.js otomatik kurulamadi. Indirme sayfasi aciliyor...'
            Start-Process 'https://nodejs.org/'
            $cevapNode = Read-Host '  Node.js kurduktan sonra Enter''a basin  [C] Cikis'
            if ($cevapNode -match '^[CcçÇ]$') { exit 0 }
            PathYenile
            if (-not (KomutVarMi 'node')) {
                Hata '  Node.js hala bulunamadi. Manuel kilavuza geciliyor.'
                ManuelRehber
                exit 1
            }
        }
    }

    $erisim = 'ANYONE'
    if ($onceki -and $onceki.Erisim) { $erisim = $onceki.Erisim }

    EskiKurulumTemizle
    DosyalariHazirla -erisim $erisim
    # Bulut adimi basarisiz olsa bile masaustu kisayolu olussun (adres varsa gomulur)
    KisayolOlustur -url $(if ($onceki -and $onceki.Url) { $onceki.Url } else { '' })
    $sonuc = Asama_OtomatikKurulum -erisim $erisim -onceki $onceki
    ConfigYaz @{
        url = $sonuc.url
        deploymentId = $sonuc.deploymentId
        scriptId = $sonuc.scriptId
        googleAccount = $sonuc.account
        erisim = $erisim
        guncelleme = (Get-Date -Format o)
        surum = $Surdur
    }
    KisayolOlustur -url $sonuc.url
    Asama4_Tamam -sonuc $sonuc -guncellendi $guncellemeMi
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
        if ($cevap -match '^[CcçÇ]$') { exit 0 }
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
    $null = Read-Host '  Kapatmak icin Enter tusuna basin'
    exit 1
}
