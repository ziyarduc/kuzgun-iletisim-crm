# Kuzgun İletişim CRM

Kuzgun İletişim (Oğuzhan Güler) için özel olarak geliştirilen CRM (Müşteri ve Cihaz Takip) sistemi.

## Özellikler

*   **Gösterge Paneli:** Dükkandaki anlık durumu, tamirdeki cihazları ve satıştaki stokları gösteren özet ekran.
*   **Tamir Takip:** Müşteriden alınan cihazların marka, model, IMEI, şifre, müşteri bilgileri ve tamir süreçlerinin takibi.
*   **Alım & Satım:** Dükkana alınan ve satılan cihazların stok ve fiyat takibi.
*   **Bulut Senkronizasyon (v1.2):** Veriler Google Sheets üzerinde tutulur; telefondan, evdeki bilgisayardan veya herhangi bir yerden aynı veriye erişilir. İnternet yoksa uygulama yerel önbellekle çalışmaya devam eder, bağlantı gelince otomatik eşitlenir (bekleyen kuyruk).
*   **Ayarlar paneli (v1.2):** PIN değiştirme, veritabanı (Sheet) bağlantısına tek tık, günlük Drive yedeğini kurma/onarma ve çıkış — hepsi telefondan yapılabilir.
*   **Yedekleme:** Tek tıkla Google Drive'a JSON yedeği (opsiyonel günlük otomatik tetikleyici) veya elle JSON dışa/içe aktarma.

## Dosyalar

| Dosya | Açıklama |
|---|---|
| `KuzgunCRM_Kurulum.exe` | **Prod kurulum (tek dosya).** Her şey gömülü (sihirbaz + kaynak kodlar); çift tıkla çalışır, dosyaları açıp sihirbazı başlatır. |
| `KuzgunCRM_Kurulum.cmd` | Çift tıklayıcı alternatif (EXE üretilemezse kaynak klasörden çalışır). |
| `Kuzgun_Iletisim_CRM.html` | Arayüz. Hem yerel dosya olarak (yerel mod) hem de Apps Script üzerinde (bulut modu) aynı dosya çalışır. |
| `Code.gs` | Google Apps Script backend: Google Sheets üzerinde CRUD, PIN doğrulama, eşzamanlılık kilidi, Drive yedeği. |
| `appsscript.json` | Apps Script manifesti (saat dilimi, V8, web uygulaması erişim ayarları). Editörde **Proje ayarları → "appsscript.json manifestini göster"** açıksa bu içerikle değiştirilebilir. |
| `Kurulum.ps1` | Sihirbazın kaynağı (bilgilendirme + gereksinim + otomatik/manuel kurulum). |
| `exe\` | EXE üretim kaynakları: `Program.cs` (gömücü/bootloader) + `Uret-Exe.ps1` (derleme betiği). |

## Kurulum

### Yol 1: Tek tıkla kurulum (önerilen)

En kolay yol: bu deponun **Releases** bölümünden `KuzgunCRM_Kurulum.exe`'yi indirin (veya repoyu klonlayın, exe depoda hazır).

Windows'ta **`KuzgunCRM_Kurulum.exe`** dosyasına **çift tıklayın** (tek dosya, tüm kurulum ve kaynaklar içine gömülüdür; ayrı kurulum gerektirmez). Sihirbaz önce **Aşama 1 – Bilgilendirme** ile neyin ne işe yaradığını anlatır (Google hesabı, Sheets, Apps Script, dosyalar, PIN, veri/gizlilik), sonra gereksinimleri kontrol eder ve kurulumu kendisi yapar:

* Gerekirse Node.js kurulum sayfasını açar, `clasp`'ı proje klasörüne kurar (yönetici yetkisi gerekmez)
* Google hesabınızla tarayıcıdan giriş aldırır, Apps Script API'yi açtırmayı hatırlatır
* Google'da yeni Apps Script projesi oluşturur, kodu yükler, web uygulaması olarak yayınlar
* Adresi kaydeder, masaüstüne "Kuzgun CRM" kısayolu koyar, CRM'i tarayıcıda açar

Sihirbaz modları: `-Bilgi` (sadece bilgilendirme), `-Hazirlik` (gereksinim raporu), `-Manuel` (adım adım kılavuz), `-Yenile` (mevcut kurulumu güncelle), `-Test` (dokunmadan doğrulama). Elle kurulum isterseniz sihirbazın "M" seçeneği veya aşağıdaki bölümler. Aynı modlar `.cmd`/`.ps1` üzerinden de çalışır.

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

İlk açılışta veriler otomatik olarak `devices` sayfasına yazılır. Günlük Drive yedeği için uygulamadaki **Ayarlar → "Günlük Drive Yedeğini Kur / Onar"** düğmesini kullanın; elle tetiklemek isteyen editörde `setupDailyBackup` fonksiyonunu bir kez çalıştırır (sonuç: 03:00'te her gün `Kuzgun CRM Yedekleri` klasörüne JSON atar, son 30 gün saklanır).

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
