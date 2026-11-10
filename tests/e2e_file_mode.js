// Masaustu HTML dosyasi (file://, Apps Script disi) -> web adresine HTTP ile baglanma testi
const src=require('fs').readFileSync(__dirname+'/e2e.js','utf8');
const head=src.slice(0,src.indexOf('(async()=>{'));
eval(head+`
(async()=>{
  const gas=makeGas();
  gas.ctx.ContentService={MimeType:{JSON:'json'},createTextOutput:t=>({t,setMimeType(){return this}})};
  const URL_='https://script.google.com/macros/s/AKfycbTEST123/exec';
  const w=await boot(gas,{cloud:false});const app=vm_(w);await sleep(200);
  ok(app.showSetup===true&&app.isCloud===false,'bağlantısız açılışta sihirbaz görünüyor (NO_BACKEND yerine)');
  w.fetch=async(url,o)=>{const out=gas.ctx.doPost({postData:{contents:o.body}});return {text:async()=>out.t}};
  app.setupUrl='http://yanlis';await app.saveSetup();
  ok(/biçiminde/.test(app.setupError),'hatalı adres reddedildi');
  app.setupUrl=URL_;await app.saveSetup();await sleep(500);
  ok(app.isCloud&&app.authed&&!app.showSetup,'adres girilince otomatik bağlandı ve oturum açıldı');
  ok(app.statusInfo&&app.statusInfo.accountEmail==='test@gmail.com','Google hesabı otomatik eşlendi');
  ok(w.localStorage.getItem('kuzgun_crm_url')===URL_,'adres kalıcı kaydedildi');
  app.openModal('REPAIR');Object.assign(app.form,{brand:'HttpTest',model:'Z'});app.saveDevice();await sleep(500);
  ok(gas.rows().some(r=>r[3]==='HttpTest'),'HTTP üzerinden kayıt Sheet\\'e yazıldı');
  await app.backupToDriveNow();await sleep(500);
  ok(gas.files.length>0,'HTTP üzerinden Drive yedeği alındı');
  // yeniden aç: kayıtlı adresle otomatik bağlan
  const w2=await boot(gas,{cloud:false,localStore:{kuzgun_crm_url:URL_}});
  w2.fetch=w.fetch;const app2=vm_(w2);
  ok(app2.isCloud===true,'kayıtlı adresle açılışta bulut modu aktif');
  // bilinmeyen islem
  const r=JSON.parse(gas.ctx.doPost({postData:{contents:JSON.stringify({fn:'getSpreadsheet_',args:[]})}}).t);
  ok(r.ok===false,'API beyaz liste dışı fonksiyonu reddetti');
  const r2=JSON.parse(gas.ctx.doPost({postData:{contents:JSON.stringify({fn:'listDevices',args:['yanlis']})}}).t);
  ok(r2.ok===false&&/PIN_HATALI/.test(r2.error),'API yanlış PIN reddi');
  console.log(fails?fails+' FAIL':'ALL OK');process.exit(fails?1:0);
})()`);
