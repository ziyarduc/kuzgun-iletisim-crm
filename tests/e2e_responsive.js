const src=require('fs').readFileSync(__dirname+'/e2e.js','utf8');
const head=src.slice(0,src.indexOf('(async()=>{'));
eval(head+`
(async()=>{
  const gas=makeGas();const w=await boot(gas);const app=vm_(w);await sleep(400);
  ok(app.autoScaleFor(500,800)<app.autoScaleFor(1366,768)&&app.autoScaleFor(2560,1440)>1,'otomatik ölçek: küçük pencere < normal < büyük ekran');
  ok(app.autoScaleFor(1920,500)<=0.9,'çok kısa pencerede ölçek küçülür');
  app.setUiScale('1.3');ok(Math.abs(parseFloat(w.document.documentElement.style.fontSize)-20.8)<0.01,'sabit ölçek uygulandı (20.8px)');
  ok(w.localStorage.getItem('kuzgun_ui_scale')==='1.3','ölçek tercihi kalıcı');
  app.setUiScale('auto');ok(/px$/.test(w.document.documentElement.style.fontSize),'otomatik ölçeğe dönüldü');
  app.scaleMenuOpen=true;await sleep(50);ok(!!w.document.querySelector('[data-testid=scale-menu]'),'ölçek menüsü açıldı');
  ok(app.uiScaleLabel==='Otomatik','etiket Otomatik');
  app.sidebarOpen=true;Object.defineProperty(w,'innerWidth',{value:1400,configurable:true});app.onResize();ok(!app.sidebarOpen,'geniş pencerede mobil menü kapanır');
  console.log(fails?fails+' FAIL':'ALL OK');process.exit(fails?1:0);
})()`);
