const fs=require('fs'),vm=require('vm'),path=require('path');
const {JSDOM}=require('jsdom');
const R=require('path').join(__dirname,'..')+'/';
let fails=0;const ok=(c,m)=>{console.log((c?'PASS':'FAIL')+' - '+m);if(!c)fails++;};
const sleep=ms=>new Promise(r=>setTimeout(r,ms));

// ---------- Apps Script mock ----------
function makeGas(){
  const props={};let rows=[[]];let sheetCreated=false;let files=[];let folders=[];let triggers=[];let idc=1;
  const cellsRange=(r,c,nr,nc)=>({
    getValues:()=>{const o=[];for(let i=0;i<nr;i++){const row=[];for(let j=0;j<nc;j++){row.push((rows[r-1+i]||[])[c-1+j]??'');}o.push(row);}return o;},
    setValues:v=>{for(let i=0;i<v.length;i++){rows[r-1+i]=rows[r-1+i]||[];for(let j=0;j<v[i].length;j++)rows[r-1+i][c-1+j]=v[i][j];}},
    clearContent:()=>{for(let i=0;i<nr;i++){rows[r-1+i]=[];}}
  });
  const sheet={getLastRow:()=>{let l=0;rows.forEach((x,i)=>{if(x&&x.some(v=>v!==''&&v!==undefined))l=i+1});return l;},
    getRange:(r,c,nr=1,nc=1)=>cellsRange(r,c,nr,nc),setFrozenRows(){},
    deleteRow:r=>{rows.splice(r-1,1)},deleteRows:(r,n)=>{rows.splice(r-1,n)}};
  const ss={getSheetByName:()=>sheetCreated?sheet:null,insertSheet:()=>{sheetCreated=true;return sheet},getId:()=>'SSID',getName:()=>'CRM',getUrl:()=>'http://x'};
  const mkFile=(name,content,folder)=>{const f={id:'F'+idc++,name,content,desc:'',trashed:false,updated:Date.now()+idc,folder,
    getId(){return this.id},getName(){return this.name},getSize(){return this.content.length},getLastUpdated(){return new Date(this.updated)},
    setTrashed(t){this.trashed=t},isTrashed(){return this.trashed},setDescription(d){this.desc=d},getDescription(){return this.desc},
    getBlob(){const c=this.content;return {getDataAsString:()=>c}},
    getParents(){const fo=this.folder;let d=false;return {hasNext:()=>!d,next:()=>{d=true;return fo}}}};files.push(f);return f;};
  const mkFolder=n=>{const fo={id:'D'+idc++,name:n,trashed:false,getId(){return this.id},getName(){return this.name},isTrashed(){return this.trashed},
    createFile(name,c){return mkFile(name,c,this)},
    getFiles(){const l=files.filter(f=>f.folder===this&&!f.trashed);let i=0;return {hasNext:()=>i<l.length,next:()=>l[i++]}},
    getFilesByName(n){const l=files.filter(f=>f.folder===this&&!f.trashed&&f.name===n);let i=0;return {hasNext:()=>i<l.length,next:()=>l[i++]}}};folders.push(fo);return fo;};
  const it=l=>{let i=0;return {hasNext:()=>i<l.length,next:()=>l[i++]}};
  const ctx={console,JSON,Date,Math,String,Number,Array,Object,Error,RegExp,
    PropertiesService:{getScriptProperties:()=>({getProperty:k=>props[k]??null,setProperty:(k,v)=>{props[k]=String(v)},deleteProperty:k=>{delete props[k]}})},
    SpreadsheetApp:{openById:()=>ss,getActiveSpreadsheet:()=>null,create:()=>ss},
    LockService:{getScriptLock:()=>({waitLock(){},releaseLock(){}})},
    ScriptApp:{getProjectTriggers:()=>triggers.map(t=>({getHandlerFunction:()=>t})),deleteTrigger(){},newTrigger:h=>({timeBased:()=>({everyDays:()=>({atHour:()=>({create:()=>{triggers.push(h)}})})})})},
    Session:{getEffectiveUser:()=>({getEmail:()=>'test@gmail.com'}),getActiveUser:()=>({getEmail:()=>'test@gmail.com'})},
    DriveApp:{getFolderById:id=>{const f=folders.find(x=>x.id===id);if(!f)throw new Error('nf');return f},
      getFoldersByName:n=>it(folders.filter(f=>f.name===n&&!f.trashed)),createFolder:mkFolder,
      getFileById:id=>{const f=files.find(x=>x.id===id);if(!f)throw new Error('nf');return f}},
    MimeType:{PLAIN_TEXT:'text/plain'},
    Utilities:{formatDate:(d,tz,fmt)=>{const p=n=>String(n).padStart(2,'0');const y=d.getFullYear(),m=p(d.getMonth()+1),dd=p(d.getDate()),H=p(d.getHours()),M=p(d.getMinutes()),S=p(d.getSeconds());return fmt.replace('yyyy',y).replace('MM',m).replace('dd',dd).replace('HHmmss',H+M+S).replace('HH',H).replace('mm',M).replace('ss',S)}},
    HtmlService:{createHtmlOutputFromFile:()=>({setTitle(){return this},addMetaTag(){return this},setXFrameOptionsMode(){return this}}),XFrameOptionsMode:{DEFAULT:1}}};
  vm.createContext(ctx);vm.runInContext(fs.readFileSync(R+'Code.gs','utf8'),ctx);
  return {ctx,files,folders,triggers,props,rows:()=>rows};
}

async function boot(gas,{cloud=true,localStore={}}={}){
  let html=fs.readFileSync(R+'Kuzgun_Iletisim_CRM.html','utf8');
  html=html.replace(/<script src="[^"]*"><\/script>/g,'').replace(/<link[^>]*>/g,'');
  const vueSrc=fs.readFileSync(''+require('path').dirname(require.resolve('vue/package.json'))+'/dist/vue.global.js','utf8');
  const dom=new JSDOM(html,{runScripts:'outside-only',pretendToBeVisual:true,url:'http://localhost/'});
  const w=dom.window;
  Object.entries(localStore).forEach(([k,v])=>w.localStorage.setItem(k,v));
  w.confirm=()=>true;w.alert=()=>{};w.URL.createObjectURL=()=>'blob:x';w.URL.revokeObjectURL=()=>{};w.HTMLAnchorElement.prototype.click=function(){w.__downloads=(w.__downloads||[]).concat(this.download)};
  w.eval(vueSrc);
  if(cloud){
    w.google={script:{run:(()=>{const mk=(ok,er)=>new Proxy({},{get(_,name){
      if(name==='withSuccessHandler')return f=>mk(f,er);
      if(name==='withFailureHandler')return f=>mk(ok,f);
      return (...a)=>setTimeout(()=>{try{const r=gas.ctx[name](...a);ok&&ok(JSON.parse(JSON.stringify(r===undefined?null:r)))}catch(e){er&&er({message:e.message})}},5)}});
      return mk();})()}};
  }
  const m=html.match(/<script>([\s\S]*?)<\/script>/i)[1];
  // expose app instance
  w.eval(m.replace(/createApp\(\{/, 'window.__app = createApp({').replace(/\}\)\.mount\(/,'}).mount(').replace(/\.mount\('#app'\)/,".mount('#app')"));
  await sleep(300);
  return w;
}
function vm_(w){return w.document.querySelector('#app').__vue_app__._instance.proxy;}

(async()=>{
  // ===== 1. cloud first login =====
  const gas=makeGas();
  let w=await boot(gas);let app=vm_(w);
  await sleep(500);
  ok(app.authed===true,'ilk girişte varsayılan PIN ile otomatik bağlandı');
  ok(app.statusInfo&&app.statusInfo.accountEmail==='test@gmail.com','Google hesabı eşlendi: '+(app.statusInfo&&app.statusInfo.accountEmail));
  ok(app.statusInfo.dailyBackupActive===true&&gas.triggers.includes('backupDaily'),'günlük yedek tetikleyicisi otomatik kuruldu');
  ok(app.devices.length===2,'demo cihazlar yüklendi ('+app.devices.length+')');

  // ===== 2. add device with date =====
  app.openModal('REPAIR');
  ok(/^\d{4}-\d\d-\d\dT\d\d:\d\d$/.test(app.form.created_at_str),'varsayılan tarih bugün: '+app.form.created_at_str);
  Object.assign(app.form,{brand:'Xiaomi',model:'Redmi 12',customer_name:'Ayşe',created_at_str:'2025-01-15T10:30'});
  app.saveDevice();await sleep(300);
  ok(app.devices.length===3,'cihaz eklendi');
  const added=app.devices.find(d=>d.brand==='Xiaomi');
  ok(new Date(added.created_at).getFullYear()===2025,'tarih değiştirilebiliyor (2025)');
  ok(gas.rows().filter(r=>r[0]!==undefined&&r[0]!=='').length===4,'Sheet\'e yazıldı');

  // ===== 3. search & date filter =====
  app.searchQuery='AYŞE';ok(app.filteredRepairs.length===1,'Türkçe büyük/küçük harf aramasında "AYŞE" bulundu');
  app.searchQuery='';app.dateFilterStart='2025-01-01';app.dateFilterEnd='2025-01-31';
  ok(app.filteredRepairs.length===1,'tarih aralığı filtresi');
  app.setQuickDate('ALL');ok(app.filteredRepairs.length>=2,'Tümü filtresi');
  app.setQuickDate('TODAY');ok(app.filteredRepairs.every(d=>new Date(d.created_at).toDateString()===new Date().toDateString()),'Bugün filtresi');
  app.setQuickDate('ALL');

  // ===== 4. Drive backup =====
  await app.backupToDriveNow();await sleep(100);
  ok(app.cloudBackups.length===1&&app.cloudBackups[0].count===3,'Drive yedeği alındı, listede 3 kayıt');
  const b1=app.cloudBackups[0];
  const bf=gas.files.find(f=>f.id===b1.id);
  ok(JSON.parse(bf.content).devices.length===3&&!('_row' in JSON.parse(bf.content).devices[0]),'yedek içeriği temiz (_row yok)');

  // delete one device, then merge restore
  app.deleteDevice(added.id);await sleep(300);
  ok(app.devices.length===2,'cihaz silindi');
  await app.openRestoreModal(b1,'merge');await sleep(100);
  ok(app.restoreStats&&app.restoreStats.added===1&&app.restoreStats.updated===2&&app.restoreStats.removed===0,'önizleme istatistikleri (merge): '+JSON.stringify(app.restoreStats));
  await app.confirmRestore();await sleep(300);
  ok(app.devices.length===3,'akıllı eşle ile silinen cihaz geri geldi');
  ok(app.snapshots.length===1,'geri yükleme öncesi anlık görüntü alındı');

  // replace restore with safety backup
  Object.assign(app.devices.find(d=>d.brand==='Samsung'),{model:'DEĞİŞTİ'});app.cacheLocal();
  app.openModal('SALE');Object.assign(app.form,{brand:'Yeni',model:'Fazla'});app.saveDevice();await sleep(300);
  ok(app.devices.length===4,'4 cihaz var');
  await app.openRestoreModal(b1,'replace');await sleep(100);
  ok(app.restoreStats.removed===1,'önizleme: 1 kayıt silinecek');
  await app.confirmRestore();await sleep(400);
  ok(app.devices.length===3&&!app.devices.find(d=>d.brand==='Yeni'),'sıfırdan değiştir: yedeğe birebir dönüldü');
  ok(gas.rows().filter(r=>r[0]!==undefined&&r[0]!=='').length===4,'Sheet de yedekle birebir (header+3)');
  await app.fetchDriveBackups();
  ok(app.cloudBackups.some(b=>b.kind==='safety'&&b.count===4),'Drive\'da güvenlik yedeği (4 kayıt) oluştu');

  // undo via snapshot
  const snap=app.snapshots[0];
  app.openRestoreFromSnapshot(snap);await app.confirmRestore();await sleep(400);
  ok(app.devices.length===snap.count,'anlık görüntüden geri alma ('+app.devices.length+' kayıt)');
  ok(gas.rows().filter(r=>r[0]!==undefined&&r[0]!=='').length===snap.count+1,'geri alma Sheet\'e de yansıdı');

  // replace with EMPTY backup must not resurrect old data
  const emptyF=gas.files[0].folder.createFile('kuzgun-crm-bos.json',JSON.stringify({devices:[]}));
  await app.fetchDriveBackups();
  const eb=app.cloudBackups.find(b=>b.name==='kuzgun-crm-bos.json');
  await app.openRestoreModal(eb,'replace');await sleep(100);await app.confirmRestore();await sleep(400);
  ok(app.devices.length===0,'boş yedekle sıfırlama: eski veriler geri dirilmedi ('+app.devices.length+')');

  // security: arbitrary file
  const evil=gas.ctx.DriveApp.createFolder('baska').createFile('kuzgun-crm-x.json','[]');
  let err='';try{gas.ctx.getDriveBackup('kuzgun-crm-2024'.replace(/.*/,'kuzgun2024'),evil.id)}catch(e){err=e.message}
  ok(err==='GECERSIZ_YEDEK','yedek klasörü dışındaki dosya reddedildi');
  err='';try{gas.ctx.listDriveBackups('yanlis')}catch(e){err=e.message}
  ok(err==='PIN_HATALI','yanlış PIN reddedildi');

  // delete backup, search filter
  await app.fetchDriveBackups();const n0=app.cloudBackups.length;
  await app.deleteDriveBackup(app.cloudBackups[0]);
  ok(app.cloudBackups.length===n0-1,'yedek silme');
  app.backupSearch='bos';ok(app.filteredBackups.every(b=>b.name.includes('bos')),'yedek arama');app.backupSearch='';
  app.backupFilter='safety';ok(app.filteredBackups.every(b=>b.kind==='safety'),'yedek türü filtresi');app.backupFilter='ALL';

  // daily backup dedupe
  gas.ctx.backupDaily();gas.ctx.backupDaily();
  const dn=gas.files.filter(f=>!f.trashed&&/^kuzgun-crm-\d{4}-\d\d-\d\d\.json$/.test(f.name));
  ok(dn.length===1,'günlük yedek aynı gün tekrar kopya üretmedi');

  // ===== 5. local mode: file import =====
  const w2=await boot(makeGas(),{cloud:false});const a2=vm_(w2);
  ok(a2.isCloud===false&&a2.devices.length===2,'yerel mod açıldı (demo 2 kayıt)');
  const payload=[{id:'a1',type:'REPAIR',brand:'Nokia',model:'3310',created_at:1700000000000},{id:'a1',brand:'dup'},{id:2,brand:'Samsung',model:'GÜNCEL'},{brand:'idsiz'}];
  a2.importBackup({target:{files:[new w2.File([JSON.stringify({devices:payload})],'x.json')],value:''}});await sleep(200);
  ok(a2.restoreModalOpen&&a2.restoreSource==='file','JSON dosyası seçilince önizleme penceresi açıldı');
  a2.importBackup({target:{files:[new w2.File(['{bozuk'],'b.json')],value:''}});await sleep(200);
  ok(/Geçersiz JSON/.test(a2.toast||''),'bozuk JSON reddedildi');
  a2.importBackup({target:{files:[new w2.File([JSON.stringify({devices:payload})],'x.json')],value:''}});await sleep(200);
  ok(a2.restoreDevices.length===2,'içe aktarmada geçersiz/yinelenen kayıtlar ayıklandı');
  ok(a2.restoreStats.added===1&&a2.restoreStats.updated===1,'yerel önizleme: +1 / 1 güncelleme');
  await a2.confirmRestore();
  ok(a2.devices.length===3&&a2.devices.find(d=>d.id==2).model==='GÜNCEL','yerel merge uygulandı');
  ok(JSON.parse(w2.localStorage.getItem('kuzgun_crm_data_v2')).length===3,'localStorage güncellendi');
  a2.restoreSource='file';a2.restoreDevices=a2.normalizeDevices(payload);a2.restoreMode='replace';a2.restoreModalOpen=true;
  await a2.confirmRestore();
  ok(a2.devices.length===2,'yerel replace uygulandı');
  a2.openRestoreFromSnapshot(a2.snapshots[0]);await a2.confirmRestore();
  ok(a2.devices.length===3,'yerel anlık görüntüden geri alma');
  a2.exportBackup();ok((w2.__downloads||[]).some(n=>/^kuzgun-crm-\d{4}/.test(n)),'JSON dışa aktarma indirmeyi tetikledi');

  // ===== 6. exit screen & fun facts =====
  const f0=a2.currentFact;let changed=false;for(let i=0;i<10;i++){a2.nextFunFact();if(a2.currentFact!==f0)changed=true;}
  ok(changed,'fun fact değişiyor');
  a2.exitApplication();await sleep(400);
  ok(/Kapatıldı/.test(w2.document.body.innerHTML)&&/Kapanış Bilgisi/.test(w2.document.body.innerHTML),'kapatma ekranı + fun fact');

  // ===== 7. wrong default PIN shows login =====
  const g3=makeGas();g3.props.ACCESS_PIN='9999';
  const w3=await boot(g3);const a3=vm_(w3);await sleep(400);
  ok(a3.authed===false&&a3.showLogin===true&&a3.pinInput==='','PIN değişmişse giriş ekranı gösterilir');
  a3.pinInput='9999';await a3.login();await sleep(300);ok(a3.authed===true,'doğru PIN ile giriş');

  console.log(fails?('\n'+fails+' TEST BAŞARISIZ'):'\nTÜM TESTLER GEÇTİ');process.exit(fails?1:0);
})().catch(e=>{console.error('HARNESS ERROR',e);process.exit(2)});
