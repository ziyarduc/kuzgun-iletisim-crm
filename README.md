# Kuzgun İletişim CRM (v2.2.0)

Kuzgun İletişim (Oğuzhan Güler) için özel olarak geliştirilen CRM (Müşteri ve Cihaz Takip) sistemi.

## Özellikler

*   **Gösterge Paneli:** Dükkandaki anlık durumu, tamirdeki cihazları ve satıştaki stokları gösteren özet ekran.
*   **Tamir Takip:** Müşteriden alınan cihazların marka, model, IMEI, şifre, müşteri bilgileri ve tamir süreçlerinin takibi.
*   **Alım & Satım:** Dükkana alınan ve satılan cihazların stok ve fiyat takibi.
*   **Bulut Senkronizasyon:** Veriler Google Sheets üzerinde tutulur; telefondan, evdeki bilgisayardan veya herhangi bir yerden aynı veriye erişilir. İnternet yoksa uygulama yerel önbellekle çalışmaya devam eder, bağlantı gelince otomatik eşitlenir (bekleyen kuyruk).
*   **Yedekleme Merkezi (v2.2):** Sol menüde özel 4. sekme! Google Drive'a tek tıkla anlık bulut yedeği alma, Drive'daki geçmiş yedekleri listeleme ve *Akıllı Eşleştirme* veya *Sıfırdan Değiştirme* seçenekleriyle anında geri yükleme.
*   **Gelişmiş Yedekleme/Geri Yükleme (v2.2):** Geri yükleme öncesi önizleme (kaç kayıt eklenecek/güncellenecek/silinecek), otomatik güvenlik yedeği (Drive + cihazda), son 5 *anlık görüntüden tek tıkla geri alma*, yedek arama/filtre, Drive yedeğini indirme/silme, JSON içe aktarmada Eşle/Sıfırdan seçimi.
*   **Düzenlenebilir Cihaz Tarihi (v2.2):** Cihaz eklerken varsayılan olarak anlık tarih ve saat otomatik gelir, istenirse takvimden geçmişe veya ileriye dönük serbestçe değiştirilebilir.
*   **Tarihe Göre Arama ve Hızlı Filtreler (v2.2):** Başlangıç ve bitiş tarih aralığı seçici ile *Bugün, Bu Hafta, Bu Ay, Tümü* hızlı butonları.
*   **Minecraft Tarzı Fun Fact Penceresi (v2.2):** Sol kenar çubuğunda ve Gösterge Paneli üstünde telefonlar ve otomobiller hakkında 30+ adet rastgele eğlenceli bilgi sunan dinamik bilgi penceresi; her açılışta, modal açma/kapatmalarda, tıklandığında ve çıkış ekranında Minecraft açılış metinleri (splash text) gibi sürpriz bilgiler gösterir.
*   **Güvenli Kapatma & Donma Koruması (v2.2):** Arayüzde "Programı Kapat" butonu, arka plan süreç kilitlenmesini engelleyen temiz süreç yönetimi ve ağ zaman aşımı (timeout) koruması.
*   **Ayarlar Paneli:** PIN değiştirme, veritabanı (Sheet) bağlantısına tek tık, günlük Drive yedeğini kurma/onarma ve çıkış.

## Dosyalar

| Dosya | Açıklama |
|---|---|
| `KuzgunCRM_Kurulum.exe` | **Prod kurulum (tek dosya v2.2.0).** Her şey gömülü (sihirbaz + kaynak kodlar); çift tıkla çalışır, dosyaları açıp sihirbazı başlatır. |
| `KuzgunCRM_Kurulum.cmd` | Çift tıklayıcı alternatif (EXE üretilemezse kaynak klasörden çalışır). |
| `Kuzgun_Iletisim_CRM.html` | Arayüz v2.2. Hem yerel dosya olarak (yerel mod) hem de Apps Script üzerinde (bulut modu) aynı dosya çalışır. |
| `Code.gs` | Google Apps Script backend: Google Sheets üzerinde CRUD, PIN doğrulama, eşzamanlılık kilidi, Drive yedek listeleme ve geri yükleme. |
| `appsscript.json` | Apps Script manifesti (saat dilimi, V8, web uygulaması erişim ayarları). |
| `Kurulum.ps1` | Sihirbazın kaynağı v2.2.0 (bilgilendirme + gereksinim + otomatik/manuel kurulum + temiz çıkış). |
| `exe\` | EXE üretim kaynakları: `Program.cs` (gömücü/bootloader v2.2) + `Uret-Exe.ps1` (derleme betiği). |

## Kurulum

### Yol 1: Tek Tıkla Otomatik Kurulum & Güncelleme (One-Click EXE - Önerilen)

En kolay yol: bu deponun **Releases** bölümünden veya doğrudan ana dizinden **`KuzgunCRM_Kurulum.exe`** dosyasını indirin ve **çift tıklayın**.

Hiçbir soru sormadan tam otomatik olarak çalışır:
* **Önceki Kurulum Algılama & Güncelleme:** Bilgisayarınızda (`%LOCALAPPDATA%\KuzgunCRM`) veya Google hesabınızda daha önce yapılmış bir kurulum varsa otomatik algılar; mevcut verilerinize dokunmadan yeni sürümü (v2.2.0) üzerine günceller.
* **Sıfırdan Kurulum:** İlk kez çalıştırılıyorsa gerekirse Node.js (winget / MSI ile sessizce) ve `clasp` aracını kurar, Google hesabınızla eşleşir, Apps Script projesini ve web yayınını otomatik oluşturur.
* **İlk Girişte Otomatik Google Hesabı Eşleme:** Kurulum biter bitmez CRM tarayıcıda açılır, varsayılan PIN ile otomatik giriş yapar, Google hesabınızı (`Session`), E-Tablo veritabanınızı ve Günlük Drive Yedeğini (her gece 03:00) otomatik olarak eşler.

İsteğe bağlı parametreler: `-Etkilesimli` (adım adım sorarak kurulum), `-Sifirdan` (mevcut kurulumu atlayıp yeni proje açma), `-Bilgi` (sadece bilgilendirme), `-Hazirlik` (gereksinim raporu), `-Manuel` (adım adım kılavuz), `-Test` (dokunmadan doğrulama).

### Yol 2: Elle kurulum (Google Apps Script)

1. https://sheets.new ile yeni bir Google E-Tablo açın.
2. **Uzantılar → Apps Script**.
3. Editördeki `Kod.gs` içeriğini silip `Code.gs` dosyasının içeriğini yapıştırın.
4. **+ → HTML** ile yeni bir dosya ekleyin, adını `index` yapın, `Kuzgun_Iletisim_CRM.html` içeriğini yapıştırın.
5. **Dağıt → Yeni dağıtım → Web uygulaması**:
   * **Çalıştırılacak kişi:** Ben
   * **Erişim izni:** Yalnızca ben (tek kullanıcı) veya şu herkes (Google hesabı ile giriş yapan ekip)
6. Oluşan `/exec` URL'ini telefonda ve bilgisayarınızda açın, PIN'i girin (telefonda **"Ana ekrana ekle"** ile uygulama gibi kullanın).

Varsayılan PIN: `kuzgun2024` — uygulama içinden **Ayarlar (dişli) → PIN değiştir** ile değiştirin (veya editörde **Proje ayarları → Script özellikleri → `ACCESS_PIN`**).

İlk açılışta veriler otomatik olarak `devices` sayfasına yazılır. Günlük Drive yedeği için uygulamadaki **Ayarlar → "Günlük Drive Yedeğini Kur / Onar"** düğmesini kullanın; elle tetiklemek isteyen editörde `setupDailyBackup` fonksiyonunu bir kez çalıştırır (sonuç: 03:00'te her gün `Kuzgun CRM Yedekleri` klasörüne JSON atar, son 40 yedek saklanır).

### Yedekten geri yükleme

Drive'daki `kuzgun-crm-YYYY-MM-DD.json` dosyasını indirin, uygulamada **İçe Aktar** ile seçin. Kayıtlar `id` üzerinden eşleştirilir; mevcut kayıt güncellenir, yeni kayıt eklenir (kopya oluşmaz).

## Günlük Kullanım Kılavuzu

**Ekranlar (sol menü):**

*   **Gösterge Paneli:** 4 sayaç — *Aktif Tamirler* (bekleyen + işlemde), *Tamamlanan Tamirler*, *Satıştaki Cihazlar* (stokta), *Satılan Cihazlar*; altta **Son İşlemler** listesi.
*   **Tamirler:** müşteri cihazı kayıtları (varsayılan durum: *Bekliyor*).
*   **Alım-Satım:** mağazadan alınıp satılan cihazlar (varsayılan durum: *Stokta*).

**Yeni tamir kaydı ekleme:**

1.  **Tamirler → "Yeni Tamir Kaydı"**.
2.  Zorunlu alanlar: **Marka** ve **Model**. Güçle önerilen: IMEI/Seri No, müşteri adı + telefon, fiyat, **Yapılan işlemler** ve **Notlar** (cihaz şifresi buraya).
3.  **Kaydet**. Kayıt hemen listeye düşer ve (bulut modda) Google Sheets'e yazılır.

**Diğer işlemler:**

*   **Arama:** üstteki kutu marka, model, müşteri ve IMEI'de anında filtreler.
*   **Düzenle:** satır sonundaki ✏ — form dolu açılır, değişikliği kaydedin (`updated_at` güncellenir).
*   **Sil:** satır sonundaki 🗑 — "emin misiniz?" onayı sorar; onaylamazsanız hiçbir şey değişmez.
*   **Durum değiştirme:** Düzenle → Durum (Bekliyor / İşlemde / Tamamlandı / Teslim Edildi — veya Stokta / Satıldı).
*   **Dışa Aktar / İçe Aktar:** üst barda; tüm kayıtları JSON olarak indirir/geri yükler (`id` üzerinden birleştirir, kopya yapmaz).
*   **Ayarlar (⚙, bulut modda):** PIN değiştirme, **Günlük Drive Yedeğini Kur / Onar**, **Şimdi Drive'a Yedekle**, Çıkış.

**Telefonda kullanma:** `/exec` adresini açın → PIN girin → tarayıcı menüsünden **"Ana ekrana ekle"** ile uygulama gibi kullanın.

**İlk açılışta** 2 örnek (demo) kayıt gelir — gerçek verileri girmeden önce silin veya kendi yedeğinizi **İçe Aktar** ile yükleyin.

**İnternet yoksa** (bulut modda) uyarı çıkar; çalışmaya yerel kopyayla devam edersiniz, bağlantı gelince bekleyen değişiklikler otomatik eşitlenir.

**Kurulumsuz (yerel) kullanım:** `Kuzgun_Iletisim_CRM.html` dosyasına çift tıklayıp tarayıcıda açabilirsiniz; veriler yalnızca o tarayıcıda (`localStorage`) tutulur. Yerel verileri buluta taşımak için yerel modda **Dışa Aktar**, bulut modda **İçe Aktar** deyin.

## Sorun Giderme

*   **PIN hatalı:** Ayarlar (⚙) → PIN değiştir; veya editörde **Proje ayarları → Script özellikleri → `ACCESS_PIN`**.
*   **Değişiklikler telefonda görünmüyor:** eski sürüm yayında olabilir — Apps Script'te **Dağıt → Dağıtımları yönet → Düzenle → Sürüm: Yeni sürüm**.
*   **Veriler kayboldu:** bulut modda **İçe Aktar** + Drive yedeği; yerel modda tarayıcı verisi silinirse geri gelmez — düzenli **Dışa Aktar** alın.
*   **Kurulum sihirbazı hata verirse:** log: `%LOCALAPPDATA%\KuzgunCRM\kurulum.log`; sihirbazı `-Manuel` moduyla da çalıştırabilirsiniz.
*   **Node.js / clasp uyarısı:** `KuzgunCRM_Kurulum.exe -Hazirlik` ile kontrol raporu alın.

## Geliştirme Notları

*   *Sürüm:* v1.2.0 — Google Sheets + Apps Script backend, uygulama içi ayarlar
*   *Tarih:* Ekim 2026
*   *Geliştirici:* Google Antigravity (AI) & Oğuzhan Güler

### Mimari notlar

*   Apps Script'te CORS header'ı eklenemez (Google kısıtı); bu yüzden arayüzün kendisi de Apps Script'te barındırılır ve `google.script.run` ile aynı origin üzerinden konuşulur.
*   Sunucu tarafı PIN doğrulaması her çağrıda yapılır (`auth_`).
*   Eşzamanlı yazmalarda `LockService` + `updated_at` bazlı son-yazan-kazanır çakışma çözümü vardır.
*   Backend'te `_` ile biten fonksiyonlar özeldir, istemciden çağrılamaz.
*   Sayfa adı `index` olmalıdır (`doGet` bu dosyayı servis eder).
*   Yeni sürüm yayınlarken **Dağıt → Dağıtımları yönet → Düzenle → Sürüm: Yeni sürüm** demeyi unutmayın; aksi halde `/exec` URL'i eski kodu çalıştırmaya devam eder.

### Testler

`crm_harness.js` (istemci: yerel mod, CRUD, PIN, ilk tohumlama, senkron, çevrimdışı kuyruk, çakışma) ve `crm_backend_test.js` (backend: auth, Sheet kurulumu, upsert/çakışma, import, delete, formül enjeksiyonu) sahte `localStorage`/`SpreadsheetApp` ile çalışır; Node ile koşturulur.

### Prod EXE üretimi

Kaynaklar değişince `KuzgunCRM_Kurulum.exe` yeniden üretilir:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File exe\Uret-Exe.ps1
```

Derleme `.NET Framework`'ün `csc.exe`'siyle yapılır (her Windows'ta vardır; ek yük gerekmez), ikon programla üretilir ve betik sonunda EXE'yi kendi `-Test`'inden geçirir. Çıktı: `KuzgunCRM_Kurulum.exe` (yaklaşık 100 KB, tüm dosyalar gömülü). `-TestiAtla` doğrulamayı atlar.

EXE çalıştığında gömülü dosyaları `%LOCALAPPDATA%\KuzgunCRM\kaynak\` altına açar ve `Kurulum.ps1`'i Windows PowerShell ile başlatır; EXE'ye verilen tüm mod argümanları sihirbaza aynen iletilir, konsol UTF-8'e (`chcp 65001`) ayarlanır. Bu nedenle `Program.cs`/`Uret-Exe.ps1` değişikliklerinde EXE'yi yeniden üretmeyi unutmayın — sihirbaz kodu EXE'nin içindedir.

## Masaüstü kısayolu ve dosyadan açılış (v2.2)
- Kurulum, masaüstüne **Kuzgun CRM.lnk** (adresi gömülü yerel kopya) ve **Kuzgun CRM (Bulut).url** kısayollarını ekler; OneDrive masaüstünü de dener. Eski sürümün masaüstü/başlangıç dosyaları `%LOCALAPPDATA%\KuzgunCRM\eski_masaustu_*` klasörüne yedeklenip kaldırılır, eski 127.0.0.1 yerel sunucusu durdurulur.
- HTML dosyası Apps Script dışında (çift tıklayarak) açılırsa **Bulut Bağlantı Sihirbazı** çıkar: `…/exec` adresi girilince varsayılan PIN ile Google hesabı otomatik eşlenir ve yedekleme/geri yükleme çalışır (`Code.gs` içindeki `doPost` JSON API'si üzerinden).
- Testler: `node tests/e2e_file_mode.js`
