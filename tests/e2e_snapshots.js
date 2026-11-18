const src = require('fs').readFileSync(__dirname + '/e2e.js', 'utf8');
const head = src.slice(0, src.indexOf('(async()=>{'));
eval(head + `
(async()=>{
  const gas=makeGas();const w=await boot(gas,{cloud:false});const app=vm_(w);await sleep(300);
  // Sahte masaüstü sunucusu (anlık görüntü RPC'leri)
  const store={};const calls=[];
  w.__STANDALONE_API__='http://127.0.0.1:18881/api';
  w.fetch=async(url,opt)=>{const m=JSON.parse(opt.body);calls.push(m.fn);let result={status:'ok'};
    if(m.fn==='saveSnapshot'){const s=m.args[1];store[s.id]=s;}
    else if(m.fn==='listSnapshots'){result=Object.values(store).map(s=>({id:s.id,ts:s.ts,reason:s.reason,count:s.count})).sort((a,b)=>b.ts-a.ts);}
    else if(m.fn==='getSnapshot'){result=store[m.args[1]];}
    else if(m.fn==='deleteSnapshot'){delete store[m.args[1]];}
    return {text:async()=>JSON.stringify({ok:true,result})};};
  // Eski tarayıcı snapshot'ları -> diske taşınmalı
  w.localStorage.setItem('kuzgun_crm_snapshots_v1',JSON.stringify([{id:'old-1',ts:1000,reason:'Eski',count:1,devices:[{id:'x1',type:'REPAIR'}]}]));
  app.pinInput='1234';
  await app.loadDiskSnapshots();
  ok(app.snapsOnDisk===true,'diskte anlık görüntü modu açıldı');
  ok(store['old-1']&&store['old-1'].devices.length===1,'eski localStorage snapshot diske taşındı');
  ok(w.localStorage.getItem('kuzgun_crm_snapshots_v1')===null,'taşıma sonrası localStorage temizlendi');
  ok(app.MAX_SNAPSHOTS===20,'sınır 20');
  ok(app.snapshots.length===1&&app.snapshots[0].id==='old-1'&&!app.snapshots[0].devices,'liste yalnızca meta içeriyor (cihaz verisi yok)');
  // Yeni görüntü
  const before=app.devices.length;
  const r=await app.takeSnapshot('Elle',true);
  ok(r===true&&Object.keys(store).length===2&&app.snapshots.length===2,'yeni anlık görüntü diske yazıldı ve liste yenilendi');
  ok(!w.localStorage.getItem('kuzgun_crm_snapshots_v1'),'tarayıcı depolamasına yazılmadı');
  const newest=app.snapshots[0];ok(store[newest.id].devices.length===before,'görüntü cihaz sayısını içeriyor ('+before+')');
  // Geri al penceresi diskten okur
  await app.openRestoreFromSnapshot(app.snapshots.find(s=>s.id==='old-1'));
  ok(app.restoreModalOpen&&app.restoreDevices.length===1&&app.restoreDevices[0].id==='x1','geri alma penceresi snapshot içeriğini diskten getirdi');
  ok(calls.includes('getSnapshot'),'getSnapshot çağrıldı');
  // Silme
  await app.removeSnapshot('old-1');
  ok(!store['old-1']&&app.snapshots.every(s=>s.id!=='old-1'),'snapshot diskten silindi');
  // Sunucu hatasında yerel depolamaya düşme
  w.fetch=async()=>{throw new Error('down');};
  app.snapsOnDisk=false;const ok2=await app.takeSnapshot('Çevrimdışı',false);
  ok(ok2===true&&JSON.parse(w.localStorage.getItem('kuzgun_crm_snapshots_v1')).length>=1,'sunucu yoksa localStorage yedeği çalışır');
  console.log(fails?fails+' FAIL':'ALL OK');process.exit(fails?1:0);
})()`);
