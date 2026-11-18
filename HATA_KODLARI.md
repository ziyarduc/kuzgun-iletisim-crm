# Kuzgun İletişim CRM — Hata Kodları & Destek Rehberi (`KZG-xxx`)

Müşteri ekranında gördüğü **`KZG-xxx`** kodunu veya **"Destek -> Destek Raporunu Kopyala"** çıktısını size ilettiğinde buradan sorunun tam kaynağını ve çözümünü görebilirsiniz.

Uygulama ayrıca her hatayı otomatik olarak:
- Tarayıcı içinde (`kuzgun_crm_error_log_v1`, son 50 kayıt)
- Bilgisayarda `%LOCALAPPDATA%\KuzgunCRM\hatalar.log` dosyasında
saklar.

---

## `KZG-1xx` — Kurulum & Başlatma Hataları

| Kod | Anlamı | Olası Neden | Çözüm |
|---|---|---|---|
| **KZG-101** | Kurulum betiği (`Kurulum.ps1`) hata verdi | Antivirüs PowerShell'i engelledi veya sistem kısıtlaması | `kurulum.log` / `hatalar.log` incelenir; kurulum yönetici veya antivirüs istisnasıyla tekrar çalıştırılır |
| **KZG-102** | `KuzgunCRM.exe` kopyalanamadı (dosya kilitli) | Eski sürüm penceresi veya arka plan sunucusu açık kalmış | Açık CRM pencerelerini kapatın (gerekirse Görev Yöneticisi → `KuzgunCRM.exe`), kurulumu yeniden çalıştırın |
| **KZG-103** | Uygulama penceresi (`Edge`/`Chrome --app`) başlatılamadı | Tarayıcı yolu bulunamadı veya erişim izni yok | Edge veya Chrome kurulu olduğundan emin olun |
| **KZG-104** | Eski yerel sunucu portu (`18881`) boşaltılamadı | Portu başka bir program veya takılı kalan eski süreç kullanıyor | Bilgisayarı yeniden başlatın veya `KuzgunCRM.exe` görevini sonlandırın |
| **KZG-105** | Gömülü kurulum dosyaları (`payload`) çıkarılamadı | Disk dolu veya `%LOCALAPPDATA%\KuzgunCRM` yazma izni yok | Disk alanını kontrol edin |
| **KZG-109** | Kurulum / EXE içinde beklenmeyen sistem hatası | Beklenmeyen .NET çalışma zamanı hatası | `%LOCALAPPDATA%\KuzgunCRM\hatalar.log` dosyasını isteyin |

---

## `KZG-2xx` — Yerel Sunucu & Arayüz (UI) Hataları

| Kod | Anlamı | Olası Neden | Çözüm |
|---|---|---|---|
| **KZG-201** | Yerel sunucu yanıt vermiyor (`127.0.0.1`) | Arka plan `-Sunucu` süreci başlamadı veya antivirüs engelledi | Masaüstü kısayolundan uygulamayı yeniden başlatın |
| **KZG-202** | Sunucu ve arayüz sürümü uyuşmuyor | Güncelleme sırasında eski sunucu süreci hafızada kalmış | Tüm Kuzgun CRM pencerelerini kapatıp yeniden açın; gerekirse `KuzgunCRM_Kurulum.exe` yeniden çalıştırın |
| **KZG-203** | Arayüz stilleri (`CSS`) yüklenemedi | Eski sunucu `/assets/` döndüremedi veya varlık engellendi | Uygulamayı kapatıp yeniden açın; online ise otomatik CDN yedeği devreye girer |
| **KZG-204** | Uygulama motoru (`Vue.js`) yüklenemedi | Yerel varlık ve CDN ikisi de yüklenemedi | Uygulamayı yeniden başlatın |
| **KZG-205** | Beklenmeyen arayüz / JavaScript hatası | UI bileşeninde yakalanmamış hata | Destek Raporundaki "Detay" satırını inceleyin |

---

## `KZG-3xx` — Veritabanı & Depolama Hataları

| Kod | Anlamı | Olası Neden | Çözüm |
|---|---|---|---|
| **KZG-301** | `veritabani.json` bozuk bulundu, `.bak` dosyasından kurtarıldı | Ani elektrik kesintisi veya zorla kapatma | **Bilgilendirme:** Veri `.bak`'tan kurtarıldı, son kaydınızı kontrol edin |
| **KZG-302** | `veritabani.json` ve `.bak` bozuk, `yedekler/` klasöründen kurtarıldı | Çoklu dosya bozulması | **Bilgilendirme:** En güncel günlük yedekten kurtarıldı |
| **KZG-303** | Disk okuma / yazma hatası | Disk dolu veya klasör salt-okunur | Disk alanını ve `%LOCALAPPDATA%\KuzgunCRM` izinlerini kontrol edin |
| **KZG-304** | Anlık görüntü (`snapshot`) kaydedilemedi / bulunamadı | Seçili anlık görüntü silinmiş veya yazma hatası | Yedekleme Merkezini yenileyin |
| **KZG-305** | Tarayıcı `localStorage` kotası doldu | Tarayıcı/dosya modunda ~5 MB sınırına ulaşıldı | Eski anlık görüntüleri temizleyin veya Masaüstü (`KuzgunCRM.exe`) modunu kullanın |

---

## `KZG-4xx` — Güvenlik & PIN Hataları

| Kod | Anlamı | Olası Neden | Çözüm |
|---|---|---|---|
| **KZG-401** | Girilen PIN kodu hatalı (`PIN_HATALI`) | Yanlış şifre girildi (ilk kurulumda varsayılan: `kuzgun2024`) | Doğru PIN'i girin veya Google Sheet içindeki `SETTINGS` / `kurulum.json` PIN'ini kontrol edin |
| **KZG-402** | Geçersiz veya kısa PIN (`PIN_KISA`) | 4 karakterden kısa PIN veya iki kutu uyuşmuyor | En az 4 karakterli aynı PIN'i girin |
| **KZG-403** | Sunucuda bilinmeyen işlem (`BILINMEYEN_ISLEM`) | Eski sunucu sürümü yeni bir API çağrısını bilmiyor | En güncel `KuzgunCRM_Kurulum.exe` ile güncelleyin |
| **KZG-404** | Geçersiz yedek veya kayıt formatı (`GECERSIZ_YEDEK`) | Bozuk JSON veya eksik `devices` alanı | Geçerli bir yedek dosyası seçin |

---

## `KZG-5xx` — Google Bulut / Sheets / Drive Hataları

| Kod | Anlamı | Olası Neden | Çözüm |
|---|---|---|---|
| **KZG-501** | Geçersiz Google Web Uygulaması (`/exec`) adresi | Kullanıcı `/edit` linkini veya yanlış URL'yi yapıştırdı | `https://script.google.com/macros/s/.../exec` formatındaki bağlantıyı kullanın |
| **KZG-502** | Google sunucusu zaman aşımı / internet kesik | İnternet yok veya Google yavaş yanıt veriyor | Veriler yerelde güvende kalır; internet gelince otomatik senkronize olur |
| **KZG-503** | Google Apps Script erişim / yetki hatası | Dağıtım `"Herkes (Anyone)"` yerine `"Yalnızca ben"` yapılmış | Apps Script → Dağıtımları yönet → Erişimi `"Herkes"` yapın |
| **KZG-504** | Çevrimdışı kuyruk buluta gönderilemedi | Arka plan senkronizasyonunda ağ hatası | Bağlantı gelince otomatik tekrar denenir |
| **KZG-505** | Drive yedek listeleme / indirme / geri yükleme hatası | Drive izni eksik veya Google kotası | Apps Script'te Drive iznini yeniden yetkilendirin |
| **KZG-506** | Günlük otomatik yedekleme tetikleyicisi kurulamadı | Apps Script Trigger yetkisi verilmemiş | Ayarlar → "Günlük Drive Yedeğini Kur / Onar" |
| **KZG-507** | Bulut bağlantısı yok (`NO_BACKEND`) | Google Bulut henüz bağlanmamışken Drive işlemi istendi | Sol menüden "Google Buluta Bağla" adımını tamamlayın |

---

## `KZG-6xx` — Veri Aktarımı & Giriş Uyarıları

| Kod | Anlamı | Olası Neden | Çözüm |
|---|---|---|---|
| **KZG-601** | Yüklenen JSON dosyası bozuk / geçersiz | Başka bir dosya veya bozuk JSON seçildi | Geçerli bir Kuzgun CRM `.json` yedeği seçin |
| **KZG-602** | Eski sürüm veri aktarımı / migrasyon hatası | Eski veritabanı okunamadı | `%LOCALAPPDATA%\KuzgunCRM\yedekler\` içindeki ham yedekler korunur |
| **KZG-603** | Tekrar eden veya daha önce satılmış IMEI uyarısı | Girilen IMEI daha önce satılmış/kayıtlı görünüyor | Müşteri Kartından cihaz geçmişini kontrol edin |
