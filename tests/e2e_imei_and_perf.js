const src = require('fs').readFileSync(__dirname + '/e2e.js', 'utf8');
const head = src.slice(0, src.indexOf('(async()=>{'));
eval(head + `
(async()=>{
  const gas=makeGas();const w=await boot(gas);const app=vm_(w);await sleep(400);
  const now=Date.now();
  // Luhn geçerli 15 haneli IMEI: 356938035643809
  const validImei='356938035643809';
  const badImei='356938035643800';
  app.devices=[
    {id:'d1',type:'REPAIR',status:'COMPLETED',brand:'Apple',model:'iPhone 13',imei:validImei,serial_number:'',customer_name:'Veli Kaya',customer_phone:'05321112233',operations_performed:'Pil',notes:'',price:900,created_at:now-86400000,updated_at:now},
    {id:'d2',type:'SALE',status:'SOLD',brand:'Samsung',model:'S24',imei:'111222333444555',serial_number:'',customer_name:'Ali Can',customer_phone:'05445556677',operations_performed:'',notes:'',price:30000,created_at:now-50000,updated_at:now}
  ];
  await sleep(50);

  // 1) Yeni kayıtta tekrar eden IMEI uyarısı
  app.openModal('REPAIR');
  app.form.imei='3569 3803 5643 809';
  await sleep(50);
  ok(app.imeiConflicts.matches.length===1&&!app.imeiConflicts.sold,'tekrar eden IMEI algılandı (boşluk normalize)');
  ok(!app.imeiLuhnWarning,'geçerli Luhn IMEI uyarı vermedi');
  ok(!!w.document.querySelector('[data-testid=imei-repeat-warn]'),'sarı tekrar IMEI banner görünüyor');

  // 2) Kendi kaydını düzenlerken kendini uyarmaz
  app.editDevice(app.devices[0]);await sleep(40);
  ok(app.imeiConflicts.matches.length===0,'düzenlemede kendi kaydı çakışma sayılmadı');

  // 3) Satılmış cihazda kırmızı KZG-603 uyarısı
  app.openModal('REPAIR');
  app.form.imei='111222333444555';
  await sleep(50);
  ok(!!app.imeiConflicts.sold&&!!w.document.querySelector('[data-testid=imei-sold-warn]'),'satılmış cihaz kırmızı KZG-603 uyarısı');
  ok(/standart dışı/.test(app.imeiLuhnWarning),'geçersiz Luhn için yumuşak uyarı gösterildi');

  // 4) Geçersiz Luhn ama boşluklu test
  app.form.imei=badImei;await sleep(30);
  ok(!!app.imeiLuhnWarning,'bozuk kontrol haneli IMEI uyarı verdi');

  // 5) Müşteri kartına IMEI uyarısından geçiş
  app.openCustomerByImei(app.devices[0]);await sleep(50);
  ok(!app.isModalOpen&&app.customerKey==='p:5321112233','uyarıdan müşteri geçmişi açıldı');

  // 6) Telefon görünüm biçimlendirme
  ok(app.formatPhone('05321234567')==='0532 123 45 67','11 hane telefon formatlandı');
  ok(app.formatPhone('+905321234567')==='0532 123 45 67','+90 telefon formatlandı');
  ok(app.formatPhone('5321234567')==='0532 123 45 67','10 hane telefon formatlandı');

  // 7) Tamir ve Satış sayfalama + localStorage debounce (>=300 kayıt)
  const many=[];
  for(let i=0;i<180;i++){
    many.push({id:'r'+i,type:'REPAIR',status:'PENDING',brand:'Apple',model:'M'+i,imei:'350000000000'+String(100+i),customer_name:'Kisi '+i,customer_phone:'05320000'+String(100+i),created_at:now-i*1000});
    many.push({id:'s'+i,type:'SALE',status:'IN_STOCK',brand:'Samsung',model:'S'+i,imei:'860000000000'+String(100+i),customer_name:'',customer_phone:'',price:1000,created_at:now-i*1000});
  }
  app.devices=many;await sleep(50);
  ok(app.filteredRepairs.length===180&&app.repairsPage.length===50,'tamir tablosu ilk sayfada 50 kayıt gösteriyor');
  ok(app.filteredSales.length===180&&app.salesPage.length===50,'satış tablosu ilk sayfada 50 kayıt gösteriyor');
  app.repairsLimit+=50;ok(app.repairsPage.length===100,'daha fazla göster limiti 100 yaptı');

  // localStorage debounce flush kontrolü
  w.localStorage.removeItem('kuzgun_crm_data_v2');
  app.cacheLocal();
  ok(w.localStorage.getItem('kuzgun_crm_data_v2')===null,'360 kayıtta localStorage yazımı hemen değil debounce bekliyor');
  app.flushLocalCache();
  ok(JSON.parse(w.localStorage.getItem('kuzgun_crm_data_v2')).length===360,'flushLocalCache veriyi eksiksiz yazdı');

  console.log(fails?fails+' FAIL':'ALL OK');process.exit(fails?1:0);
})()`);
