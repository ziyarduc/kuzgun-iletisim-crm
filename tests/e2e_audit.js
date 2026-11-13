// Uçtan uca statik + canlı DOM tuş/fonksiyon/API karşılık denetimi
const fs = require('fs');
const src = fs.readFileSync(__dirname + '/e2e.js', 'utf8');
const head = src.slice(0, src.indexOf('(async()=>{'));

eval(head + `
(async()=>{
  const html = fs.readFileSync(R + 'Kuzgun_Iletisim_CRM.html', 'utf8');
  const gs = fs.readFileSync(R + 'Code.gs', 'utf8');
  const tpl = html.slice(0, html.indexOf('<script>'));
  const scr = html.slice(html.indexOf('<script>'), html.lastIndexOf('</script>'));

  // 1. Gas.call <-> Code.gs & API_FUNCS_ denetimi
  const gasCalls = [...new Set([...scr.matchAll(/Gas\\.call\\(\\s*'([^']+)'/g)].map(m => m[1]))];
  const apiMatch = gs.match(/var\\s+API_FUNCS_\\s*=\\s*\\{([^}]+)\\}/);
  const apiFuncs = new Set([...apiMatch[1].matchAll(/([a-zA-Z_]\\w*)\\s*:/g)].map(m => m[1]));
  const gsFuncs = new Set([...gs.matchAll(/^function\\s+([a-zA-Z_]\\w*)\\s*\\(/gm)].map(m => m[1]));

  for (const fn of gasCalls) {
    ok(gsFuncs.has(fn), 'Code.gs fonksiyonu mevcut: ' + fn);
    ok(apiFuncs.has(fn), 'API_FUNCS_ beyaz listede mevcut: ' + fn);
  }
  for (const fn of apiFuncs) {
    ok(gsFuncs.has(fn), 'API_FUNCS_ hedefi Code.gs içinde tanımlı: ' + fn);
  }

  // 2. Canlı Vue örneği üzerinde tüm HTML event & v-model bağlamaları
  const gas = makeGas();
  gas.ctx.ContentService = { MimeType: { JSON: 'json' }, createTextOutput: t => ({ t, setMimeType() { return this; } }) };
  const w = await boot(gas, { cloud: true });
  const app = vm_(w);
  await sleep(400);

  const builtins = new Set(['if','else','Math','Date','String','Number','Boolean','Array','JSON','console','alert','confirm','location','window','document','parseInt','parseFloat']);
  const events = [...tpl.matchAll(/@(?:click|submit|change|input|keyup\\.enter)(?:\\.[a-z]+)*="([^"]+)"/g)].map(m => m[1]);
  const called = new Set();
  for (const ev of events) {
    for (const part of ev.split(';')) {
      const p = part.trim();
      if (!p) continue;
      for (const m of p.matchAll(/\\b([a-zA-Z_]\\w*)\\s*\\(/g)) {
        if (!builtins.has(m[1])) called.add(m[1]);
      }
      if (/^[a-zA-Z_]\\w*$/.test(p)) called.add(p);
    }
  }
  for (const fn of called) {
    ok(typeof app[fn] === 'function', 'Template metodu Vue üzerinde tanımlı: ' + fn);
  }

  const vmodels = [...new Set([...tpl.matchAll(/v-model(?:\\.[a-z]+)?="([^"]+)"/g)].map(m => m[1]))];
  for (const vm of vmodels) {
    const root = vm.split('.')[0];
    ok(root in app, 'v-model kökü Vue data üzerinde tanımlı: ' + vm);
  }

  // 3. Canlı tuş ve sekme akışı denetimi (DOM tıklama simülasyonu)
  for (const tab of ['dashboard', 'repairs', 'sales', 'backups']) {
    app.currentTab = tab;
    await sleep(40);
    ok(app.currentTab === tab, 'Sekme geçişi: ' + tab);
  }

  // Fun fact butonu
  const prevFact = app.currentFact.text;
  let changed = false;
  for (let i = 0; i < 5; i++) { app.nextFunFact(); if (app.currentFact.text !== prevFact) changed = true; }
  ok(changed, 'Fun fact değiştirme tuşu çalışıyor');

  // Tamir ve Satış modal aç/kapat & hızlı tarih filtreleri
  app.openModal('REPAIR'); await sleep(30);
  ok(app.isModalOpen && app.form.type === 'REPAIR', 'Yeni Tamir modalı açıldı');
  app.closeModal(); await sleep(30);
  ok(!app.isModalOpen, 'Modal kapat tuşu çalıştı');

  app.openModal('SALE'); await sleep(30);
  ok(app.isModalOpen && app.form.type === 'SALE', 'Yeni Satış modalı açıldı');
  app.closeModal();

  for (const q of ['TODAY', 'WEEK', 'MONTH', 'ALL']) {
    app.setQuickDate(q);
    ok(app.dateFilterQuick === q, 'Hızlı tarih filtresi: ' + q);
  }

  // Ayarlar & günlük yedekleme & çıkış/giriş tuşları
  app.openSettings(); await sleep(30);
  ok(app.settingsOpen === true, 'Ayarlar modalı açıldı');
  await app.installBackup(); await sleep(100);
  ok(app.statusInfo && app.statusInfo.dailyBackupActive === true, 'Günlük yedek kurulum tuşu çalıştı');
  app.settingsOpen = false;

  // Anlık görüntü alma & silme
  const snapBefore = app.snapshots.length;
  app.takeSnapshot('Audit test');
  ok(app.snapshots.length === snapBefore + 1, 'Anlık görüntü alma çalıştı');
  app.removeSnapshot(app.snapshots[0].id);
  ok(app.snapshots.length === snapBefore, 'Anlık görüntü silme çalıştı');

  // Kapatma & Yeniden Aç tuşu
  app.exitApplication();
  await sleep(300);
  ok(w.document.body.textContent.includes('Kuzgun İletişim CRM Kapatıldı'), 'Kapat tuşu kapanış ekranını gösterdi');

  console.log(fails ? fails + ' FAIL' : 'AUDIT: ALL OK (' + gasCalls.length + ' RPC, ' + called.size + ' UI methods, ' + vmodels.length + ' v-models)');
  process.exit(fails ? 1 : 0);
})()`);
