// Gerçek tarayıcı (Chromium) düzen testi: farklı pencere boyutlarında taşma, "Kaydet" görünürlüğü, toast çakışması.
// Gereksinim: npm i playwright-core ; CHROMIUM=/usr/bin/chromium  (yoksa test atlanır)
// Çalıştırma: node tests/browser/layout.js
const { spawn } = require('child_process');
const path = require('path');
let chromium; try { chromium = require('playwright-core').chromium; } catch (e) { console.log('SKIP - playwright-core yok'); process.exit(0); }
const exe = process.env.CHROMIUM || '/usr/bin/chromium';
if (!require('fs').existsSync(exe)) { console.log('SKIP - Chromium yok: ' + exe); process.exit(0); }
let fails = 0; const ok = (c, m) => { console.log((c ? 'PASS' : 'FAIL') + ' - ' + m); if (!c) fails++; };
(async () => {
  const srv = spawn('node', [path.join(__dirname, 'serve.js')], { stdio: 'ignore' });
  await new Promise(r => setTimeout(r, 1200));
  const b = await chromium.launch({ executablePath: exe, args: ['--no-sandbox'] });
  const sizes = [[2560, 1440], [1920, 1080], [1366, 640], [1024, 600], [800, 560], [480, 800], [360, 640]];
  for (const [w, h] of sizes) {
    const p = await b.newPage({ viewport: { width: w, height: h } });
    await p.goto('http://127.0.0.1:18899/', { waitUntil: 'load' }); await p.waitForTimeout(700);
    await p.evaluate(() => { window.__VM.showSetup = false; });
    const cssCheck = await p.evaluate(() => {
      const aside = document.querySelector('aside');
      const bg = aside ? getComputedStyle(aside).backgroundColor : '';
      return { bg, broken: !!window.__VM.cssBrokenBanner, ver: window.__VM.appVersion };
    });
    ok(cssCheck.bg === 'rgb(17, 24, 39)' && !cssCheck.broken, `${w}x${h}: Tailwind CSS gercek tarayicida yuklendi (${cssCheck.bg})`);
    for (const tab of ['dashboard', 'repairs', 'sales', 'customers', 'backups']) {
      await p.evaluate(t => { window.__VM.currentTab = t; }, tab); await p.waitForTimeout(100);
      const o = await p.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 1);
      ok(!o, `${w}x${h} ${tab}: yatay taşma yok`);
    }
    await p.evaluate(() => { const a = window.__VM; a.currentTab = 'repairs'; a.openModal('REPAIR'); a.toast = 'Test bildirimi'; }); await p.waitForTimeout(250);
    const r = await p.evaluate(() => {
      const bt = [...document.querySelectorAll('button')].find(x => /Kaydet/.test(x.textContent) && x.offsetParent);
      const t = document.querySelector('[data-testid=toast]');
      const a = bt.getBoundingClientRect(), c = t ? t.getBoundingClientRect() : null;
      const inter = c && !(c.right < a.left || c.left > a.right || c.bottom < a.top || c.top > a.bottom);
      return { vis: a.bottom <= innerHeight + .5 && a.top >= 0 && a.right <= innerWidth + .5, inter };
    });
    ok(r.vis, `${w}x${h} modal: Kaydet görünür alanda`);
    ok(!r.inter, `${w}x${h} modal: toast Kaydet düğmesini örtmüyor`);
    await p.close();
  }
  await b.close(); srv.kill();
  console.log(fails ? fails + ' FAIL' : 'ALL OK'); process.exit(fails ? 1 : 0);
})();
