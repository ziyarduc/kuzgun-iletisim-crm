const src = require('fs').readFileSync(__dirname + '/e2e.js', 'utf8');
const head = src.slice(0, src.indexOf('(async()=>{'));
eval(head + `
(async()=>{
  const gas=makeGas();const w=await boot(gas);const app=vm_(w);await sleep(400);
  // 1) Sınıflandırma kontrolleri
  ok(w.classifyError('PIN_HATALI')==='KZG-401','PIN_HATALI -> KZG-401');
  ok(w.classifyError('en az 4')==='KZG-402','PIN kısa -> KZG-402');
  ok(w.classifyError('BILINMEYEN_ISLEM')==='KZG-403','BILINMEYEN_ISLEM -> KZG-403');
  ok(w.classifyError('ZAMAN_ASIMI')==='KZG-502','ZAMAN_ASIMI -> KZG-502');
  ok(w.classifyError('NO_BACKEND')==='KZG-507','NO_BACKEND -> KZG-507');
  ok(w.classifyError('GECERSIZ_YEDEK')==='KZG-404','GECERSIZ_YEDEK -> KZG-404');
  ok(w.classifyError('bambaşka beklenmeyen şey')==='KZG-205','bilinmeyen hata -> KZG-205');

  // 2) showToast error kodu otomatik ekler ve loga + standalone sunucuya gönderir
  const sent=[];
  w.__STANDALONE_API__='http://127.0.0.1:18881/api';
  w.fetch=async(u,o)=>{sent.push(JSON.parse(o.body));return{text:async()=>'{"ok":true}'};};
  let copied='';
  w.navigator.clipboard={writeText:t=>{copied=t;return Promise.resolve();}};

  app.showToast('PIN hatalı.','error');await sleep(50);
  ok(app.toast.startsWith('[KZG-401]')&&app.toastCode==='KZG-401','hata toast başında [KZG-401] var');
  ok(app.lastErrorCode==='KZG-401'&&app.errorLogs.length>=1,'lastErrorCode ve errorLogs güncellendi');
  ok(sent.some(x=>x.fn==='logClientError'&&x.args[0]==='KZG-401'),'standalone sunucuya logClientError gönderildi');

  // 3) copyErrorReport çıktı formatı
  app.copyErrorReport();await sleep(30);
  ok(copied.includes('KZG-401')&&copied.includes('v'+app.appVersion),'Destek raporu KZG kodu ve sürüm içeriyor');

  // 4) Destek Merkezi modalı açılır ve listeler
  app.openErrorCenter();await sleep(60);
  const modal=w.document.querySelector('[data-testid=error-center]');
  ok(!!modal&&modal.textContent.includes('KZG-401'),'Destek & Hata Merkezi modalı açıldı ve hatayı gösterdi');
  app.clearErrorLogs();await sleep(30);
  ok(app.errorLogs.length===0&&app.lastErrorCode==='','hata geçmişi temizlendi');

  // 5) Sürüm uyuşmazlığı (KZG-202) ve DB kurtarma notu (KZG-301) tespiti
  gas.ctx.crmStatus_orig=gas.ctx.crmStatus;
  gas.ctx.crmStatus=(pin)=>Object.assign(gas.ctx.crmStatus_orig(pin),{isStandalone:true,version:'2.4.0',recoveryNote:'veritabani.json bozuk: .bak kurtarildi',recoveryCode:'KZG-301'});
  await app.connect(true);await sleep(50);
  ok(app.errorLogs.some(e=>e.code==='KZG-202'),'sunucu-arayüz sürüm uyuşmazlığı KZG-202 yakalandı');
  ok(app.errorLogs.some(e=>e.code==='KZG-301'),'DB .bak kurtarma uyarısı KZG-301 yakalandı');

  console.log(fails?fails+' FAIL':'ALL OK');process.exit(fails?1:0);
})()`);
