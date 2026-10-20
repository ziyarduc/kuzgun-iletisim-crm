#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Bilgi,
    [switch]$Hazirlik,
    [switch]$Manuel,
    [switch]$Yenile,
    [switch]$Test
)

$ErrorActionPreference = 'Stop'
$Kaynak = $PSScriptRoot
$Ana = Join-Path $env:LOCALAPPDATA 'KuzgunCRM'
$Proje = Join-Path $Ana 'proje'
$Surdur = 'v1.2.0'
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
    if ($varsayilan -ne '') { $cevap = Read-Host ("  Enter = devam (" + $varsayilan + ")") }
    else { $cevap = Read-Host '  Enter ile devam edin' }
    return $cevap
}
function BaglantiVarMi {
    try {
        $r = Invoke-WebRequest -Uri 'https://www.google.com/generate_204' -Method Head -UseBasicParsing -TimeoutSec 10
        return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400)
    } catch { return $false }
}
function KomutVarMi { param([string]$ad) return [bool](Get-Command $ad -ErrorAction SilentlyContinue) }

function Asama1_Bilgilendirme {
    Baslik 'ASAMA 1 - BILGILENDIRME (neyin ne ise yaradigi)'
    Bilgi 'Bu program, Kuzgun Iletisim CRM''ini Google''in bulutuna kurar; size tek bir'
    Bilgi 'web adresi + PIN verir. Telefonda uygulama gibi acilir. Adim adim anlatim:'
    Write-Host ''
    Satir White '  1) GOOGLE HESABI (ucretsiz, ~2 dakika)'
    Satir Gray '     - Veriler Google''in bulutunda tutulacagi icin bir Google (Gmail) hesabi sart.'
    Satir Gray '     - Hesabiniz yoksa: https://accounts.google.com  ->  "Hesap olusturun"'
    Satir Gray '       Adiniz,@sifreniz, telefon dogrulamasi. Bu islemi siz yaparsiniz;'
    Satir Gray '       program sizin adiniza hesap acamaz ve sifrenizi goremez.'
    Write-Host ''
    Satir White '  2) GOOGLE SHEETS (E-Tablo) = BULUT EXCEL'
    Satir Gray '     - Normal Excel gibi tablo, ama dosya Google''in sunucusunda: her cihazdan acilir.'
    Satir Gray '     - Bizim VERITABANIMIZ bu. Kurulumda "Kuzgun Iletisim CRM Verileri"'
    Satir Gray '       adli E-Tablo sizin Drive''inizda otomatik olusur.'
    Write-Host ''
    Satir White '  3) APPS SCRIPT = GOOGLE''IN UCRETSIZ KOD MOTORU'
    Satir Gray '     - Kendi sunucunuz, hosting, alan adi, aylik ucret YOK. Kod Google''da calisir.'
    Satir Gray '     - Uygulamanin uc parzasi:'
    Write-Host '       * Code.gs     -> BEYIN/SUNUCU: E-Tablo''ya yazar-okuur, PIN kontrolu, yedek.' -ForegroundColor Gray
    Write-Host '       * index       -> YUZ: ekran, menu, butonlar (tarayicida gorunur).' -ForegroundColor Gray
    Write-Host '       * appsscript  -> AYAR: saat dilimi, kimler erisebilir (manifest).' -ForegroundColor Gray
    Satir Gray '     - Yayindan sonra ortaya CIKAN TEK SEY: bir web adresi (.../exec).'
    Write-Host ''
    Satir White '  4) WEB UYGULAMASI (YAYIN)'
    Satir Gray '     - Kurulum sonunda elinizde kalacak iki sey: ADRES + PIN (varsayilan: kuzgun2024).'
    Satir Gray '     - Telefonda: adresi ac -> PIN gir -> menu -> "Ana ekrana ekle".'
    Write-Host ''
    Satir White '  5) PIN VE GUVENLIK'
    Satir Gray '     - PIN her istekte SUNUCUDA kontrol edilir; bilen girer. Ilk giristen sonra'
    Satir Gray '       Ayarlar (disli ikon) ile degistirin.'
    Satir Gray '     - Uygulama "Ben" olarak yayinlanir: kod sizin hesabinizda calisir.'
    Write-Host ''
    Satir White '  6) BU PROGRAM NE YAPAR / NE YAPMAZ'
    Satir Green '     Yapar : gereksinim kontrolu, gerekirse Node.js/clasp indirir, dosyalari'
    Satir Green '             hazirlar, Google''da yeni Apps Script projesi olusturur, kodu'
    Satir Green '             yukler, yayinlar, adresi kaydeder, masaustu kisayolu olusturur.'
    Satir Red '     Yapmaz: sizin yerinize Google hesabi acmaz, sifrenizi saklamaz, sunucu/'
    Satir Red '             hizmet kurmaz (sadece kucuk bir calisma klasoru), mevcut dosyalarinizi silmez.'
    Write-Host ''
    Satir White '  7) VERI NEREDE, YEDEK NEREDE?'
    Satir Gray '     - Ana veri : sizin Google E-Tablonuz (Drive).'
    Satir Gray '     - Gunluk yedek: Drive''da "Kuzgun CRM Yedekleri" (JSON, son 30 gun).'
    Satir Gray '     - Bu PC: %LOCALAPPDATA%\KuzgunCRM (adres, proje kopyasi) + tarayici onbellegi.'
    Satir Gray '     - Geri almak isterseniz: ucretli bir abonelik YOK; her seyi silebilirsiniz.'
    Write-Host ''
}

function Asama2_Gereksinim {
    Basari '  [ ] Internet baglantisi ...'
    $net = BaglantiVarMi
    if ($net) { Basari ('  [OK] Internet: var (' + (Get-Date -Format HH:mm:ss) + ')') }
    else { Hata '  [X] Internet yok!' }

    $nodeOk = $false; $nodeS = 'YOK'
    if (KomutVarMi 'node') {
        $nodeS = (& node -v 2>&1 | Out-String).Trim()
        $major = 0; [void][int]::TryParse(($nodeS -replace '[^0-9]', ''), [ref]$major)
        $major = [int]($nodeS -replace '^v(\d+)\..*$', '$1')
        if ($major -ge 16) { $nodeOk = $true; Basari ("  [OK] Node.js: " + $nodeS) }
        else { Uyari ("  [!] Node.js eski: " + $nodeS + ' (16+ gerekli)') }
    } else { Uyari '  [!] Node.js yok (otomatik kurulum icin gerekli; manuel mod gerekmez)' }

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
    else { Uyari '  [ ] clasp kurulacak (otomatik modda, proje klasorune; yonetici yetkisi gerekmez)' }

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
    if (Test-Path $yol) { return (Get-Content $yol -Raw | ConvertFrom-Json) } return $null
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
    $cikti = & $yol @Argumanlar 2>&1 | Out-String
    $kod = $LASTEXITCODE
    $script:ClaspLog += "`n$ clasp $($Argumanlar -join '')`n$cikti"
    if ($kod -ne 0) {
        throw ("clasp basarisiz ($Is, kod $kod):`n" + $cikti.Trim())
    }
    return $cikti
}

function Asama_OtomatikKurulum {
    param([string]$erisim)

    Adim 'Clasp (Google aracisi) kuruluyor'
    if (-not (ClaspYoluBul)) {
        Uyari '    Proje icine clasp kuruluyor (npm, ~1 dk)...'
        Push-Location $Proje
        & npm i @google/clasp --no-fund --no-audit 2>&1 | Select-Object -Last 3 | ForEach-Object { Write-Host ('    ' + $_) -ForegroundColor DarkGray }
        Pop-Location
        if (-not (ClaspYoluBul)) { throw 'clasp kurulamadi (npm/node kontrol edin)' }
    }
    Basari '    [OK] clasp hazir'

    Adim 'Google ile giris (tarayici acilacak)'
    Uyari '    Tarayicida Google hesabinizla giris yapin ve izin verin.'
    Uyari '    Bu pencereden ayriLMAYIN; islem bitince otomatik devam eder.'
    $yetkili = $false
    try { $out = Clasp-Cagir -Argumanlar @('show-authorized-user') -Sessiz; $yetkili = ($out -match '@') } catch { $yetkili = $false }
    if (-not $yetkili) {
        $null = Clasp-Cagir -Argumanlar @('login')
        Basari '    [OK] Google girisi tamam'
    } else { Basari '    [OK] Zaten giris yapilmis' }

    Adim 'Apps Script API acik mi? (tarayici acilacak)'
    Uyari '    Acan sayfada "Apps Script API" anahtarini ACIK yapin, sonra Enter''a basin.'
    Start-Process 'https://script.google.com/home/usersettings'
    $null = Read-Host '    Hazir olunca Enter'
    Start-Sleep -Seconds 1

    $cikarilmis = $false
    if (Test-Path (Join-Path $Proje '.clasp.json')) {
        $claspCfg = Get-Content (Join-Path $Proje '.clasp.json') -Raw | ConvertFrom-Json
        if ($claspCfg.scriptId) { $cikarilmis = $true; Basari '    [OK] Mevcut Apps Script projesi kullanilacak' }
    }
    if (-not $cikarilmis) {
        Adim 'Google''da yeni Apps Script projesi olusturuluyor'
        $null = Clasp-Cagir -Argumanlar @('create-script', '--title', 'Kuzgun Iletisim CRM', '--type', 'webapp', '--rootDir', '.')
        Basari '    [OK] Proje olusturuldu'
    }

    Adim 'Kod yukleniyor (push)'
    $null = Clasp-Cagir -Argumanlar @('push', '--force')
    Basari '    [OK] Code.gs + index.html + manifest yuklendi'

    Adim 'Yayin (web uygulamasi)'
    $deploymentId = $null
    $eskiCfg = ConfigOku
    if ($eskiCfg -and $eskiCfg.deploymentId) { $deploymentId = $eskiCfg.deploymentId }
    $aciklama = 'Kuzgun CRM ' + (Get-Date -Format 'yyyy-MM-dd HH:mm')
    $cikti = ''
    if ($deploymentId) {
        $cikti = Clasp-Cagir -Argumanlar @('create-deployment', '-i', $deploymentId, '-d', $aciklama, '--json')
    } else {
        $cikti = Clasp-Cagir -Argumanlar @('create-deployment', '-d', $aciklama, '--json')
    }
    try {
        $j = $cikti | Select-String -Pattern '\{[\s\S]*\}' | ForEach-Object { $_.Matches[0].Value } | Select-Object -First 1
        $dep = $j | ConvertFrom-Json
        if ($dep.deploymentId) { $deploymentId = $dep.deploymentId }
    } catch {}
    if (-not $deploymentId) { Uyari '    [!] deploymentId okunamadi, URL adimi deneniyor' }
    else { Basari '    [OK] Yayin olusturuldu' }

    Adim 'Web adresi aliniyor'
    $url = $null
    if ($deploymentId) {
        try {
            $cikti2 = Clasp-Cagir -Argumanlar @('open-web-app', $deploymentId, '--json') -Sessiz
            if ($cikti2 -match 'https://script\.google\.com[^\s"]*exec') { $url = $Matches[0] }
        } catch {}
    }
    if (-not $url) {
        try {
            $cikti3 = Clasp-Cagir -Argumanlar @('list-deployments', '--json') -Sessiz
            if ($cikti3 -match 'https://script\.google\.com[^\s"]*exec') { $url = $Matches[0] }
        } catch {}
    }
    if (-not $url) { throw 'Web uygulamasi adresi alinamadi. Clasp loguna bakin veya yayini tarayicida elle tamamlayin.' }
    Basari ('    [OK] ' + $url)

    return @{ url = $url; deploymentId = $deploymentId }
}

function Asama4_Tamam {
    param([hashtable]$sonuc)
    Baslik 'ASAMA 4 - TAMAMLANDI'
    Basari '  CRM yayinda:'
    Satir White ('    ADRES : ' + $sonuc.url)
    Satir White '    PIN   : kuzgun2024  (ilk giristen sonra AYARLARDAN degistirin)'
    Write-Host ''
    Satir Gray '  - Telefonunuzda adesi acin, PIN girin, menu > "Ana ekrana ekle".'
    Satir Gray '  - Masaustune "Kuzgun CRM" kisayolu eklendi.'
    Satir Gray '  - Gunluk yedek: uygulama ici Ayarlar > "Gunluk Drive Yedeğini Kur".'
    Satir Gray '  - Guncelleme icin: KuzgunCRM_Kurulum.cmd dosyasini tekrar calistirin.'
    Write-Host ''
    if ($script:ClaspLog) {
        $log = Join-Path $Ana 'kurulum.log'
        Set-Content -Path $log -Value $script:ClaspLog -Encoding UTF8
        Satir Gray ('  Kurulum logu: ' + $log)
    }
    Start-Process $sonuc.url
}

function KisayolOlustur {
    param([string]$url)
    try {
        $masaustu = [Environment]::GetFolderPath('Desktop')
        $sc = Join-Path $masaustu 'Kuzgun CRM.url'
        "[InternetShortcut]`r`nURL=$url" | Set-Content $sc -Encoding ASCII
        Basari ('  [OK] Masaustu kisayolu: ' + $sc)
    } catch { Uyari ('  [!] Kisayol olusturulamadi: ' + $_.Exception.Message) }
}

function GuncellemeYap {
    param($mevcut)
    $d = Asama2_Gereksinim
    if (-not ($d.Internet -and $d.Node -and $d.Npm -and $d.Kaynak)) {
        Hata '  Guncelleme icin gereksinimler eksik. Node.js: https://nodejs.org'
        exit 1
    }
    $erisim = 'ANYONE'
    if ($mevcut -and $mevcut.erisim) { $erisim = $mevcut.erisim }
    DosyalariHazirla -erisim $erisim
    $sonuc = Asama_OtomatikKurulum -erisim $erisim
    ConfigYaz @{ url = $sonuc.url; deploymentId = $sonuc.deploymentId; erisim = $erisim; guncelleme = (Get-Date -Format o); surum = $Surdur }
    KisayolOlustur -url $sonuc.url
    Asama4_Tamam -sonuc $sonuc
}

function ManuelRehber {
    Baslik 'MANUEL KILAVUZ (adim adim, yaklasik 10 dakika)'
    Bilgi 'Otomatik kurulum calismazsa bu adimlari izleyin. Her adimda ne ise'
    Bilgi 'yaradigi yaziyor.'
    Write-Host ''
    Satir White '  A) Google hesabi (yoksa): https://accounts.google.com  -> Hesap olusturun'
    Satir White '  B) Yeni E-Tablo (bulut Excel = veritabani): https://sheets.new'
    Satir White '  C) Uzantilar > Apps Script (kod motoru)'
    Satir White '  D) Code.gs icerigini yapistirin (kopyala-yapistir):'
    Satir Gray ('       notepad "' + (Join-Path $Kaynak 'Code.gs') + '"')
    Satir Gray '     Notepad > Tamamini sec (Ctrl+A), kopyala (Ctrl+C) > editore yapistir (Ctrl+V).'
    Satir White '  E) + > HTML dosyasi, adini "index" yapin, HTML icerigini yapistirin:'
    Satir Gray ('       notepad "' + (Join-Path $Kaynak 'Kuzgun_Iletisim_CRM.html') + '"')
    Satir White '  F) Apps Script API anahtarini ACIN (yoksa yayin hata verir):'
    Satir Gray '       https://script.google.com/home/usersettings'
    Satir White '  G) Dagitim > Yeni dagitim > Web uygulamasi:'
    Satir Gray '       Calistirilacak kisi: Ben   |   Erisim izni: Su herkes'
    Satir White '  H) Verilen /exec adresini acin, PIN: kuzgun2024'
    Satir White '  I) Icinde: Ayarlar (disli) > PIN degistir + Gunluk Drive Yedeğini Kur'
    Write-Host ''
    Satir Yellow ('  Not: Kod ve HTML dosyalari bu klasorde: ' + $Kaynak)
    Uyari '  Hazir olunca tek yapmaniz gereken G adimindaki URL''yi kaydetmektir.'
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
        ConfigYaz @{ url = 'https://script.google.com/macros/s/TEST/exec'; deploymentId = 'D1' }
        $geri = ConfigOku
        if ($geri.url -like '*exec') { Basari '  [OK] kurulum bilgisi yazma/okuma' } else { Hata '  [X] config yuvarlak yol'; $basarili = $false }

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

    $ornek = '{"deploymentId":"AbCd123","versionNumber":3,"description":"x"}'
    $dep = $ornek | ConvertFrom-Json
    if ($dep.deploymentId -eq 'AbCd123') { Basari '  [OK] clasp create-deployment --json cikti okuma' } else { Hata '  [X] json okuma'; $basarili = $false }

    $ornekUrl = "Deployed AbCd123`nhttps://script.google.com/macros/s/AKfycb/execute"
    if ($ornekUrl -match 'https://script\.google\.com[^\s"]*exec') { Basari '  [OK] URL yakalama deseni' } else { Hata '  [X] URL yakalama'; $basarili = $false }

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

    $mevcutConfig = ConfigOku
    if ($Yenile) {
        if ($mevcutConfig -and $mevcutConfig.url) {
            Baslik 'ONCEKI KURULUM GUNCELLENIYOR'
            Satir White ('    ADRES : ' + $mevcutConfig.url)
            GuncellemeYap $mevcutConfig
            exit 0
        }
        Uyari '  Kurulum bilgisi bulunamadi; tam kurulum olarak devam ediliyor.'
    }

    Asama1_Bilgilendirme
    $null = Devam

    Baslik 'ASAMA 2 - GEREKSINIM KONTROLU'
    $durum = Asama2_Gereksinim

    $mevcut = ConfigOku
    if ($mevcut -and $mevcut.url) {
        Baslik 'ONCEKI KURULUM BULUNDU'
        Satir White ('    ADRES : ' + $mevcut.url)
        $cevap = Read-Host '  [G] Guncelle (Enter)  [Y] Yeni kurulum (sifirdan)'
        if ($cevap -ne 'Y') {
            GuncellemeYap $mevcut
            exit 0
        }
    }

    Baslik 'ASAMA 3 - KURULUM'
    if (-not $durum.Node) {
        Uyari '  Node.js kurulu degil (otomatik kurulumun motoru).'
        Uyari '  Tarayici aciliyor: indirin, kurun, sonra Enter''a basin.'
        Start-Process 'https://nodejs.org/'
        $null = Read-Host '  Kurduysaniz Enter'
        if (-not (KomutVarMi 'node')) {
            Hata '  Node.js hala gorunmuyor. Manuel kilavuza geciliyor.'
            Write-Host ''
            ManuelRehber
            exit 1
        }
    }

    $cevap = Read-Host '  Kurulum modu  [O] Otomatik (Enter)  [M] Manuel kilavuz'
    if ($cevap -eq 'M') { ManuelRehber; exit 0 }

    $erisim = 'ANYONE'
    $cevap2 = Read-Host '  Erisim izni  [A] Google girisi zorunlu (Enter, onerilen)  [B] girissiz herkes acabilsin'
    if ($cevap2 -eq 'B') { $erisim = 'ANYONE_ANONYMOUS' }

    DosyalariHazirla -erisim $erisim
    $sonuc = Asama_OtomatikKurulum -erisim $erisim
    ConfigYaz @{ url = $sonuc.url; deploymentId = $sonuc.deploymentId; kurulum = (Get-Date -Format o); erisim = $erisim; surum = $Surdur }
    KisayolOlustur -url $sonuc.url
    Asama4_Tamam -sonuc $sonuc
    exit 0
}
catch {
    Write-Host ''
    Hata ('KURULUM DURDU: ' + $_.Exception.Message)
    Write-Host ''
    Uyari '  Yayin adiminda sorun olursa elle tamamlayabilirsiniz:'
    Uyari '   1) https://script.google.com/home/usersettings -> Apps Script API acik olsun'
    Uyari '   2) Script editoru: clasp login durumunu Dogrulamak icin: clasp show-authorized-user'
    Uyari '   3) Veya asagidaki MANUEL KILAVUZU ile ilerleyin:'
    Write-Host ''
    ManuelRehber
    if ($script:ClaspLog) {
        $log = Join-Path $Ana 'kurulum.log'
        if (-not (Test-Path $Ana)) { New-Item -ItemType Directory -Path $Ana -Force | Out-Null }
        Set-Content -Path $log -Value $script:ClaspLog -Encoding UTF8
        Satir Gray ('  Ayrinti: ' + $log)
    }
    exit 1
}
