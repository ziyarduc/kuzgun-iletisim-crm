const src = require('fs').readFileSync(__dirname + '/e2e.js', 'utf8');
const head = src.slice(0, src.indexOf('(async()=>{'));
eval(head + `
(async()=>{
  const gas=makeGas();const w=await boot(gas);const app=vm_(w);await sleep(500);
  const mk=(i,o)=>Object.assign({id:'t'+i,type:'REPAIR',status:'PENDING',brand:'Apple',model:'iPhone 11',imei:'35'+i,serial_number:'',customer_name:'',customer_phone:'',operations_performed:'',notes:'',price:100,created_at:Date.now()-i*1000},o);
  app.devices=[
    mk(1,{customer_name:'Ahmet Yılmaz',customer_phone:'0532 111 22 33',model:'iPhone 13',price:1500}),
    mk(2,{customer_name:'Ahmet Yilmaz',customer_phone:'+905321112233',type:'SALE',status:'SOLD',brand:'Samsung',model:'S23',price:20000}),
    mk(3,{customer_name:'Işık Demir',customer_phone:'05449998877',operations_performed:'Ekran değişimi',status:'IN_PROGRESS'}),
    mk(4,{customer_name:'Sadece İsim',customer_phone:''}),
    mk(5,{customer_name:'sadece isim',customer_phone:''}),
    mk(6,{customer_name:'',customer_phone:'',type:'SALE',status:'IN_STOCK',brand:'Xiaomi',model:'Redmi'})
  ];
  await sleep(50);
  ok(app.customerList.length===3,'telefon yazım farkları tek müşteri; isim-only birleşir; mağaza stoğu dışarıda ('+app.customerList.length+')');
  const ahmet=app.customerList.find(c=>c.key==='p:5321112233');
  ok(ahmet&&ahmet.devices.length===2&&ahmet.total===21500&&ahmet.repairs===1&&ahmet.sales===1,'Ahmet toplam/sayaç doğru');
  ok(app.customerList.find(c=>c.key==='n:sadece isim').devices.length===2,'isim-only anahtar büyük/küçük harf duyarsız');
  app.searchQuery='isik';ok(app.filteredRepairs.length===1&&app.filteredRepairs[0].id==='t3','Türkçe duyarsız arama: isik -> Işık');
  app.searchQuery='ahmet iphone';ok(app.filteredRepairs.length===1,'çok kelimeli AND (tamir)');
  app.searchQuery='ahmet samsung';ok(app.filteredSales.length===1,'satış aramasında müşteri adı da aranıyor');
  app.searchQuery='532 111';ok(app.filteredRepairs.length===1,'telefon rakam araması boşluklu');
  app.searchQuery='ekran';ok(app.filteredRepairs.length===1,'tamir aramasında işlem/not aranıyor');
  app.searchQuery='';
  app.globalQuery='ahmet';ok(app.globalResults.customers.length===1&&app.globalResults.devices.length===2,'global arama müşteri+cihaz');
  ok(app.hl('Işık Demir','isik')==='<mark>Işık</mark> Demir','vurgulama TR duyarsız');
  ok(app.hl('<b>x</b>','x').indexOf('<b>')<0,'vurgulama XSS kaçışı');
  ok(app.waLink('0532 111 22 33')==='https://wa.me/905321112233','WhatsApp bağlantısı');
  app.currentTab='customers';await sleep(80);
  ok(/Ahmet Y/.test(w.document.body.textContent)&&w.document.querySelector('[data-testid=customers-tab]'),'müşteriler sekmesi render');
  app.openCustomerByKey('p:5321112233');await sleep(80);
  ok(w.document.querySelector('[data-testid=customer-card]')&&/21500/.test(w.document.body.textContent),'müşteri kartı açıldı');
  app.newForCustomer('REPAIR');await sleep(50);
  ok(app.isModalOpen&&app.form.customer_phone==='0532 111 22 33','kartan yeni tamir müşteri dolu');
  app.form.customer_phone='';app.form.customer_name='Ahmet Yılmaz';app.autofillCustomer();
  ok(app.form.customer_phone==='0532 111 22 33','formda isimden telefon otomatik tamamlama');
  app.openGlobalSearch();await sleep(50);
  ok(w.document.querySelector('[data-testid=global-search]'),'global arama açıldı');
  w.dispatchEvent(new w.KeyboardEvent('keydown',{key:'Escape'}));await sleep(50);
  ok(!app.globalOpen,'Esc ile kapandı');
  // performans 5000 kayıt
  const big=[];for(let i=0;i<5000;i++)big.push(mk('b'+i,{customer_name:'Musteri '+(i%800),customer_phone:'0533'+String(1000000+i%800),brand:'Brand'+(i%30)}));
  app.devices=big;await sleep(50);
  let t0=Date.now();app.searchQuery='musteri 77 brand';const n=app.filteredRepairs.length;const dt=Date.now()-t0;
  ok(dt<500&&n>0,'5000 kayıtta arama '+dt+' ms');
  console.log(fails?fails+' FAIL':'ALL OK');process.exit(fails?1:0);
})()`);
