// Standalone sunucuyu taklit eder: HTML'e __STANDALONE_API__ ekler, /assets/* servis eder, /api'ye örnek veri döner.
const http = require('http'), fs = require('fs'), path = require('path');
const R = require('path').join(__dirname, '..', '..') + '/';
const now = Date.now();
const devs = [
  { id: 1, type: 'REPAIR', status: 'IN_PROGRESS', brand: 'Apple', model: 'iPhone 13 Pro Max', imei: '123456789012345', serial_number: 'F2LXK', customer_name: 'Ahmet Yılmaz Uzunisimli Müşteri', customer_phone: '0532 123 4567', operations_performed: 'Ekran değişimi ve batarya', notes: 'Şifre: 1453', price: 4500, created_at: now - 86400000, updated_at: now },
  { id: 2, type: 'SALE', status: 'IN_STOCK', brand: 'Samsung', model: 'Galaxy S23 Ultra', imei: '987654321098765', serial_number: 'R5CW32', customer_name: '', customer_phone: '', operations_performed: '', notes: 'Kutulu sıfır', price: 35000, created_at: now - 3600000, updated_at: now },
  { id: 3, type: 'REPAIR', status: 'COMPLETED', brand: 'Xiaomi', model: 'Redmi Note 12', imei: '111222333444555', serial_number: '', customer_name: 'Işık Demir', customer_phone: '0544 999 8877', operations_performed: 'Şarj soketi', notes: '', price: 850, created_at: now - 7200000, updated_at: now }
];
http.createServer((q, r) => {
  if (q.url.startsWith('/assets/')) {
    const f = R + q.url.split('?')[0].slice(1);
    if (fs.existsSync(f)) {
      r.writeHead(200, { 'Content-Type': { '.css': 'text/css', '.js': 'application/javascript', '.woff2': 'font/woff2' }[path.extname(f)] || 'application/octet-stream' });
      return r.end(fs.readFileSync(f));
    }
    r.writeHead(404); return r.end();
  }
  if (q.url.startsWith('/api')) {
    let b = ''; q.on('data', d => b += d);
    q.on('end', () => {
      let m = {}; try { m = JSON.parse(b); } catch (e) {}
      const fn = m.fn || ''; let result = { ok: true };
      if (fn === 'crmStatus') result = { mode: 'standalone', spreadsheet: 'Yerel', dailyBackupActive: true, version: '2.4.3', isStandalone: true };
      else if (fn === 'listDevices') result = devs;
      else if (fn === 'listDriveBackups') result = [];
      r.writeHead(200, { 'Content-Type': 'application/json' }); r.end(JSON.stringify({ ok: true, result }));
    });
    return;
  }
  let h = fs.readFileSync(R + 'Kuzgun_Iletisim_CRM.html', 'utf8');
  h = h.replace('const { createApp } = Vue', "window.__STANDALONE_SERVER__ = true; window.__STANDALONE_API__ = 'http://127.0.0.1:18899/api';\n        const { createApp } = Vue");
  h = h.replace('        createApp({', '        window.__VM = createApp({');
  r.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' }); r.end(h);
}).listen(18899, '127.0.0.1', () => console.log('up'));
