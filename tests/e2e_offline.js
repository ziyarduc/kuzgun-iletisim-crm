// Çevrimdışı varlık denetimi: standalone modda HTML yalnızca yerel /assets/* kullanır,
// tüm yerel varlıklar mevcuttur, FontAwesome yazı tipi yolları çözülür, dış bağlantılar yalnızca CDN dalındadır.
const fs = require('fs');
const path = require('path');
const R = path.join(__dirname, '..') + '/';
let fails = 0;
const ok = (c, m) => { console.log((c ? 'PASS' : 'FAIL') + ' - ' + m); if (!c) fails++; };

const html = fs.readFileSync(R + 'Kuzgun_Iletisim_CRM.html', 'utf8');

// 1) Loader betiği çıkarılıp her iki modda çalıştırılır
const m = html.match(/<script id="kuzgun-asset-loader">([\s\S]*?)<\/script>/);
ok(!!m, 'varlık yükleyici betiği bulundu');
const loaderSrc = m[1];
function run(loc) {
  const out = [];
  new Function('location', 'document', loaderSrc)(loc, { write: s => out.push(s) });
  return out.join('\n');
}
const standalone = run({ protocol: 'http:', hostname: '127.0.0.1', port: '18881' });
const filemode = run({ protocol: 'file:', hostname: '', port: '' });
const gas = run({ protocol: 'https:', hostname: 'script.google.com', port: '' });

ok(!/https?:\/\/(cdn\.tailwindcss|cdnjs|unpkg)/.test(standalone.replace(/if \(!window\.Vue\)[^\n]*/, '')),
   'standalone modda CDN yok (yalnızca Vue yerel yükleme başarısızsa yedek)');
ok(/\/assets\/vue\.global\.prod\.js/.test(standalone) && /\/assets\/tailwind\.css/.test(standalone) && /\/assets\/css\/fa\.min\.css/.test(standalone),
   'standalone modda 3 yerel varlık kullanılıyor');
ok(/cdn\.tailwindcss\.com/.test(filemode) && /cdn\.tailwindcss\.com/.test(gas), 'dosya ve Apps Script modunda CDN kullanılıyor');
ok(!/vue\.global\.js/.test(standalone), 'standalone modda development build yok');

// 2) Dosyalar mevcut ve makul boyutta
const files = ['assets/vue.global.prod.js', 'assets/tailwind.css', 'assets/css/fa.min.css',
  'assets/webfonts/fa-solid-900.woff2', 'assets/webfonts/fa-regular-400.woff2', 'assets/webfonts/fa-brands-400.woff2'];
files.forEach(f => ok(fs.existsSync(R + f) && fs.statSync(R + f).size > 5000, 'varlık mevcut: ' + f));

// 3) FontAwesome ../webfonts/ yolları assets/webfonts altında çözülüyor
const fa = fs.readFileSync(R + 'assets/css/fa.min.css', 'utf8');
const urls = [...fa.matchAll(/url\(\.\.\/webfonts\/([^)]+)\)/g)].map(x => x[1]).filter(x => x.endsWith('.woff2'));
ok(urls.length >= 3 && urls.every(u => fs.existsSync(R + 'assets/webfonts/' + u)), 'FontAwesome woff2 yolları çözülüyor: ' + [...new Set(urls)].join(', '));

// 4) Kullanılan tüm Tailwind sınıfları derlenmiş CSS içinde (örnek kritik sınıflar)
const tw = fs.readFileSync(R + 'assets/tailwind.css', 'utf8');
['.bg-gray-900', '.rounded-xl', '.lg\\:static', '.min-\\[420px\\]\\:grid-cols-3', '.backdrop-blur-sm', '.max-w-2xl', '.divide-y', '.bg-opacity-60', '.animate-pulse', '.hover\\:bg-gray-50:hover']
  .forEach(c => ok(tw.includes(c), 'Tailwind sınıfı derlenmiş: ' + c));

// 5) Vue prod yapısı
const vue = fs.readFileSync(R + 'assets/vue.global.prod.js', 'utf8');
ok(!/__VUE_PROD_DEVTOOLS__|development build/.test(vue.slice(0, 2000)) && vue.length > 100000, 'Vue production build');

// 6) build.sh tüm varlıkları gömüyor ve sunucu yolu mevcut
const sh = fs.readFileSync(R + 'build.sh', 'utf8');
['vue.global.prod.js', 'tailwind.css', 'css/fa.min.css', 'fa-solid-900.woff2', 'fa-regular-400.woff2', 'fa-brands-400.woff2', 'fa-v4compatibility.woff2'].forEach(f => ok(sh.includes(f), 'build.sh gömüyor: ' + f));
const cs = fs.readFileSync(R + 'exe/Program.cs', 'utf8');
ok(/StartsWith\("\/assets\/"/.test(cs) && /GetEmbeddedAsset/.test(cs) && /IndexOf\("\.\."/.test(cs), 'sunucu /assets/ yolu ve yol gezinmesi koruması var');

console.log(fails ? fails + ' FAIL' : 'ALL OK');
process.exit(fails ? 1 : 0);
