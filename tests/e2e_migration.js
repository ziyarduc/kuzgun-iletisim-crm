// tests/e2e_migration.js
// Kapsamlı Eski Sürüm (v1/v2) Migrasyonu, EMBED_DEVICES ve Code.gs Şema Güvenliği E2E Testi
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const { JSDOM } = require('jsdom');

const R = path.join(__dirname, '..') + '/';
let fails = 0;
const ok = (cond, msg) => {
  console.log((cond ? 'PASS' : 'FAIL') + ' - ' + msg);
  if (!cond) fails++;
};
const sleep = ms => new Promise(r => setTimeout(r, ms));

// e2e.js içindeki makeGas ve temel ortamı al
const e2eSrc = fs.readFileSync(path.join(__dirname, 'e2e.js'), 'utf8');
const head = e2eSrc.slice(0, e2eSrc.indexOf('(async()=>{'));
eval(head);

// Özel boot fonksiyonu (html manipülasyonu / embedDevices desteği)
async function bootCustom(gas, { cloud = true, localStore = {}, embedDevices = null, customHtml = null } = {}) {
  let html = customHtml || fs.readFileSync(R + 'Kuzgun_Iletisim_CRM.html', 'utf8');
  if (embedDevices && Array.isArray(embedDevices)) {
    html = html.replace('const EMBED_DEVICES = [];', 'const EMBED_DEVICES = ' + JSON.stringify(embedDevices) + ';');
  }
  html = html.replace(/<script src="[^"]*"><\/script>/g, '').replace(/<link[^>]*>/g, '');
  const vueSrc = fs.readFileSync(path.dirname(require.resolve('vue/package.json')) + '/dist/vue.global.js', 'utf8');
  const dom = new JSDOM(html, { runScripts: 'outside-only', pretendToBeVisual: true, url: 'http://localhost/' });
  const w = dom.window;

  Object.entries(localStore).forEach(([k, v]) => w.localStorage.setItem(k, typeof v === 'string' ? v : JSON.stringify(v)));
  w.confirm = () => true;
  w.alert = () => {};
  w.URL.createObjectURL = () => 'blob:x';
  w.URL.revokeObjectURL = () => {};
  w.HTMLAnchorElement.prototype.click = function () {
    w.__downloads = (w.__downloads || []).concat(this.download);
  };
  w.eval(vueSrc);

  if (cloud) {
    w.google = {
      script: {
        run: (() => {
          const mk = (onOk, onEr) => new Proxy({}, {
            get(_, name) {
              if (name === 'withSuccessHandler') return f => mk(f, onEr);
              if (name === 'withFailureHandler') return f => mk(onOk, f);
              return (...a) => setTimeout(() => {
                try {
                  const r = gas.ctx[name](...a);
                  onOk && onOk(JSON.parse(JSON.stringify(r === undefined ? null : r)));
                } catch (e) {
                  onEr && onEr({ message: e.message });
                }
              }, 5);
            }
          });
          return mk();
        })()
      }
    };
  }

  const m = html.match(/<script>([\s\S]*?)<\/script>/i)[1];
  w.eval(m.replace(/createApp\(\{/, 'window.__app = createApp({').replace(/\}\)\.mount\(/, '}).mount(').replace(/\.mount\('#app'\)/, ".mount('#app')"));
  await sleep(300);
  return w;
}

(async () => {
  console.log('=== TEST 1: Legacy v1 Data Loss-Free Migration (kuzgun_crm_data) ===');
  {
    const gas = makeGas();
    const legacyV1Data = [
      {
        id: 101,
        musteri_adi: 'Mehmet Öz',
        telefon: '0544 987 6543',
        cihaz_marka: 'Xiaomi',
        cihaz_model: 'Redmi Note 11',
        seri_no: 'SN101XYZ',
        imei_no: '861234567890123',
        yapilan_islem: 'Batarya ve şarj soketi değişimi',
        sifre: '9876',
        fiyat: '1.450,50 ₺',
        tur: 'tamir',
        durum: 'bekliyor',
        kayit_tarihi: 1700000000000
      },
      {
        id: 102,
        musteri_adi: 'Ayhan Demir',
        telefon: '0555 111 2233',
        marka: 'Apple',
        model: 'iPhone 11 128GB',
        seri_no: 'SN102APP',
        sifre: '',
        fiyat: '18.500 TL',
        tur: 'satis',
        durum: 'stokta',
        tarih: '2024-05-10T14:30:00.000Z'
      }
    ];

    // LocalStore'a sadece legacy 'kuzgun_crm_data' konuluyor (kuzgun_crm_data_v2 boş)
    const w = await bootCustom(gas, {
      cloud: false,
      localStore: {
        kuzgun_crm_data: JSON.stringify(legacyV1Data)
      }
    });
    const app = vm_(w);
    await sleep(200);

    // 1.1 Pre-migrate ham yedek alındı mı?
    const premigrateRaw = w.localStorage.getItem('kuzgun_crm_backup_premigrate');
    ok(premigrateRaw !== null, 'Migrasyon öncesi ham veri kuzgun_crm_backup_premigrate anahtarına yedeklendi');
    if (premigrateRaw) {
      const pm = JSON.parse(premigrateRaw);
      ok(pm.raw_legacy && pm.raw_legacy.includes('Mehmet Öz'), 'Ham yedek legacy verisini eksiksiz içeriyor');
    }

    // 1.2 Kayıtlar v2.2 kanonik şemasına normalize edildi mi?
    ok(app.devices.length === 2, 'Eski 2 kayıt başarıyla yüklendi (demoDevices ezmedi, sayı: ' + app.devices.length + ')');
    const d101 = app.devices.find(d => d.id === 101);
    const d102 = app.devices.find(d => d.id === 102);

    ok(d101 && d101.customer_name === 'Mehmet Öz', 'Alan eşleme: musteri_adi -> customer_name (Mehmet Öz)');
    ok(d101 && d101.brand === 'Xiaomi' && d101.model === 'Redmi Note 11', 'Alan eşleme: cihaz_marka/model -> brand/model');
    ok(d101 && d101.serial_number === 'SN101XYZ', 'Alan eşleme: seri_no -> serial_number');
    ok(d101 && d101.operations_performed === 'Batarya ve şarj soketi değişimi', 'Alan eşleme: yapilan_islem -> operations_performed');
    ok(d101 && d101.type === 'REPAIR' && d101.status === 'PENDING', 'Türkçe enum: tamir -> REPAIR, bekliyor -> PENDING');
    ok(d101 && d101.price === 1450.5, 'Türkçe para formatı dönüştürüldü (1.450,50 ₺ -> 1450.5)');
    ok(d101 && d101.notes.includes('Şifre: 9876'), 'Eski sifre alanı notlara güvenle aktarıldı: ' + (d101 && d101.notes));

    ok(d102 && d102.type === 'SALE' && d102.status === 'IN_STOCK', 'Türkçe enum: satis -> SALE, stokta -> IN_STOCK');
    ok(d102 && d102.price === 18500, 'Türkçe para formatı dönüştürüldü (18.500 TL -> 18500)');

    // 1.3 LocalStorage v2 güncellendi mi?
    const v2Stored = JSON.parse(w.localStorage.getItem('kuzgun_crm_data_v2') || '[]');
    ok(v2Stored.length === 2 && v2Stored.some(d => d.id === 101), 'Kayıtlar kuzgun_crm_data_v2 içerisine kalıcı yazıldı');
  }

  console.log('\n=== TEST 2: EMBED_DEVICES Injection & No Demo Override ===');
  {
    const gas = makeGas();
    const embeddedRecords = [
      {
        id: 201,
        type: 'REPAIR',
        status: 'IN_PROGRESS',
        brand: 'Huawei',
        model: 'P30 Pro',
        customer_name: 'Fatma Şahin',
        customer_phone: '0533 222 3344',
        operations_performed: 'Kamera lensi onarımı',
        price: 950,
        created_at: 1710000000000
      }
    ];

    // Temiz localStorage, HTML içine EMBED_DEVICES enjekte edilmiş
    const w = await bootCustom(gas, {
      cloud: false,
      localStore: {},
      embedDevices: embeddedRecords
    });
    const app = vm_(w);
    await sleep(200);

    ok(app.devices.length === 1, 'Gömülü kayıt yüklendi (toplam: ' + app.devices.length + ')');
    ok(app.devices[0].brand === 'Huawei' && app.devices[0].customer_name === 'Fatma Şahin', 'EMBED_DEVICES içeriği korundu');
    ok(!app.devices.some(d => d.id === 1 || d.id === 2), 'demoDevices gömülü veriyi ezmedi (demo kayıt yok)');

    // Şimdi hem EMBED_DEVICES hem de localStorage v2 verisi varken açılış testi (ID çakışmasında v2 önceliği)
    const existingV2 = [
      {
        id: 201,
        type: 'REPAIR',
        status: 'COMPLETED',
        brand: 'Huawei',
        model: 'P30 Pro Guncel',
        customer_name: 'Fatma Şahin',
        customer_phone: '0533 222 3344',
        operations_performed: 'Kamera lensi tamamlandı',
        price: 1100,
        created_at: 1710000000000
      },
      {
        id: 202,
        type: 'SALE',
        status: 'IN_STOCK',
        brand: 'Sony',
        model: 'WH-1000XM4',
        customer_name: '',
        price: 6500,
        created_at: 1710000050000
      }
    ];

    const w2 = await bootCustom(gas, {
      cloud: false,
      localStore: {
        kuzgun_crm_data_v2: existingV2
      },
      embedDevices: embeddedRecords
    });
    const app2 = vm_(w2);
    await sleep(200);

    ok(app2.devices.length === 2, 'Kullanıcının mevcut verisi ve gömülü veri çakışmasız birleşti (2 kayıt)');
    const rec201 = app2.devices.find(d => d.id === 201);
    ok(rec201 && rec201.model === 'P30 Pro Guncel' && rec201.status === 'COMPLETED', 'ID çakışmasında kullanıcının yerel v2 kaydı korundu');
  }

  console.log('\n=== TEST 3: Code.gs Formula Injection Protection & Normalization Mock ===');
  {
    const gas = makeGas();

    // 3.1 toRow_ ve toObject_ formül koruması testi
    // Sheet'e formül olabilecek karakterlerle (=, +, -, @) başlayan değerler gönderiliyor
    const formulaDevice = {
      id: 301,
      type: 'REPAIR',
      status: 'PENDING',
      brand: '=SUM(A1:A10)', // Formül enjeksiyonu denemesi
      model: '-Tehlikeli Model',
      imei: '@imeiRef',
      serial_number: '+905321112233',
      customer_name: '=CMD|calc',
      customer_phone: '+905329998877',
      operations_performed: '- Ekran değişimi',
      notes: '+ Kasa temizliği yapıldı',
      price: 2500,
      created_at: 1715000000000,
      updated_at: 1715000000000
    };

    // upsertDevice çağrısı (PIN korumalı)
    const upsertRes = gas.ctx.upsertDevice('kuzgun2024', formulaDevice);
    ok(upsertRes && upsertRes.status === 'ok', 'upsertDevice formül enjeksiyonlu kaydı kabul etti');

    // Sheet ham satırlarını kontrol et: Başında apostrof var mı?
    const rawSheetRows = gas.rows();
    const targetRow = rawSheetRows.find(r => String(r[0]) === '301');
    ok(targetRow !== undefined, 'Kayıt Sheet satırlarına eklendi');

    // COLUMNS: ['id', 'type', 'status', 'brand', 'model', 'imei', 'serial_number', 'customer_name', 'customer_phone', 'operations_performed', 'notes', 'price', 'created_at', 'updated_at']
    // brand (index 3), model (4), imei (5), serial_number (6), customer_name (7), customer_phone (8), operations (9), notes (10)
    ok(targetRow && targetRow[3] === "'=SUM(A1:A10)", "Sheet hücresinde formül apostrof ile kaçırıldı: '=SUM(A1:A10)");
    ok(targetRow && targetRow[4] === "'-Tehlikeli Model", "Sheet hücresinde '-' apostrof ile kaçırıldı: '-Tehlikeli Model");
    ok(targetRow && targetRow[5] === "'@imeiRef", "Sheet hücresinde '@' apostrof ile kaçırıldı: '@imeiRef");
    ok(targetRow && targetRow[7] === "'=CMD|calc", "Sheet hücresinde musteri_adi formülü kaçırıldı: '=CMD|calc");
    ok(targetRow && targetRow[8] === "'+905329998877", "Sheet hücresinde telefon no '+90...' kaçırıldı: '+905329998877");

    // Şimdi listDevices ile geri okuma: Apostroflar arayüze/istemciye temizlenerek mi dönüyor?
    const readDevices = gas.ctx.listDevices('kuzgun2024');
    const readDev = readDevices.find(d => String(d.id) === '301');
    ok(readDev !== undefined, 'listDevices kaydı başarıyla getirdi');
    ok(readDev && readDev.brand === '=SUM(A1:A10)', 'Geri okumada apostrof kaldırıldı: brand == =SUM(A1:A10)');
    ok(readDev && readDev.customer_phone === '+905329998877', 'Geri okumada telefon temizlendi: +905329998877');
    ok(readDev && readDev.operations_performed === '- Ekran değişimi', 'Geri okumada operasyon temizlendi: - Ekran değişimi');

    // 3.2 Code.gs normalizeDevice_ ve importDevices testi
    const legacyRawBatch = [
      {
        kayit_id: 302,
        musteri_adi: 'Kemal Sunal',
        telefon: '+905320000000',
        marka: 'Nokia',
        cihaz: '3310',
        seriNo: 'NK3310',
        sifre: '4455',
        fiyat: '2.500,00 TL',
        tur: 'tamir',
        durum: 'tamamlandi'
      }
    ];

    const importRes = gas.ctx.importDevices('kuzgun2024', legacyRawBatch, true);
    ok(importRes && importRes.status === 'ok', 'Code.gs importDevices eski Türkçe şemayı kabul etti');
    ok(importRes.added === 1, '1 kayıt başarıyla eklendi');
    ok(importRes.safetyBackup !== undefined, 'Güvenlik yedeği oluşturuldu');

    const read302 = gas.ctx.listDevices('kuzgun2024').find(d => String(d.id) === '302');
    ok(read302 && read302.customer_name === 'Kemal Sunal', 'Code.gs normalizasyonu: musteri_adi -> customer_name');
    ok(read302 && read302.brand === 'Nokia' && read302.model === '3310', 'Code.gs normalizasyonu: cihaz -> model');
    ok(read302 && read302.notes.includes('Şifre: 4455'), 'Code.gs normalizasyonu: sifre notlara eklendi');
    ok(read302 && read302.status === 'COMPLETED', 'Code.gs normalizasyonu: tamamlandi -> COMPLETED');
    ok(read302 && read302.price === 2500, 'Code.gs normalizasyonu: 2.500,00 TL -> 2500');

    // 3.3 doPost üzerinden setupDailyBackup çağrısı
    gas.ctx.ContentService = {
      MimeType: { JSON: 'json' },
      createTextOutput: t => ({ t, setMimeType() { return this; } })
    };

    // Yanlış PIN ile setupDailyBackup
    const postWrong = gas.ctx.doPost({
      postData: {
        contents: JSON.stringify({ fn: 'setupDailyBackup', args: ['yanlis_pin'] })
      }
    });
    const parsedWrong = JSON.parse(postWrong.t);
    ok(parsedWrong.ok === false && /PIN_HATALI/.test(parsedWrong.error), 'doPost setupDailyBackup yanlış PIN reddi');

    // Doğru PIN ile setupDailyBackup
    const postOk = gas.ctx.doPost({
      postData: {
        contents: JSON.stringify({ fn: 'setupDailyBackup', args: ['kuzgun2024'] })
      }
    });
    const parsedOk = JSON.parse(postOk.t);
    ok(parsedOk.ok === true && parsedOk.result && parsedOk.result.status === 'ok', 'doPost setupDailyBackup doğru PIN ile başarılı');
    ok(gas.triggers.includes('backupDaily'), 'backupDaily tetikleyicisi ScriptApp altına kaydedildi');
  }

  console.log('\n=== TEST 4: No Data Overwrite & Empty DB Preservation ===');
  {
    const gas = makeGas();

    // 4.1 Kullanıcı veritabanını bilerek sıfırlamışsa (kuzgun_crm_data_v2: [])
    // demoDevices geri dirilmemelidir.
    const wEmpty = await bootCustom(gas, {
      cloud: false,
      localStore: {
        kuzgun_crm_data_v2: []
      }
    });
    const appEmpty = vm_(wEmpty);
    await sleep(200);

    ok(appEmpty.devices.length === 0, 'Kullanıcının boşalttığı veritabanı korundu (demoDevices hortlamadı, 0 kayıt)');

    // 4.2 replaceAllDevices güvenlik yedeği garantisi
    const replaceRes = gas.ctx.replaceAllDevices('kuzgun2024', [
      { id: 401, type: 'SALE', status: 'IN_STOCK', brand: 'Casper', model: 'Via', price: 4000 }
    ], true);
    ok(replaceRes && replaceRes.status === 'ok', 'replaceAllDevices başarıyla çalıştı');
    ok(replaceRes.safetyBackup && replaceRes.safetyBackup.name.includes('kuzgun-crm-oncesi-'), 'replaceAllDevices öncesi Drive güvenlik yedeği alındı: ' + (replaceRes.safetyBackup && replaceRes.safetyBackup.name));
  }

  console.log('\n======================================================');
  if (fails > 0) {
    console.error(`E2E MIGRATION: ${fails} TEST BAŞARISIZ!`);
    process.exit(1);
  } else {
    console.log('E2E MIGRATION: TÜM TESTLER BAŞARIYLA GEÇTİ (PASS - ALL OK)');
    process.exit(0);
  }
})().catch(e => {
  console.error('E2E MIGRATION HARNESS ERROR:', e);
  process.exit(2);
});
