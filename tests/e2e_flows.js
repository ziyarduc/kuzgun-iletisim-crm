const src=require('fs').readFileSync(__dirname+'/e2e.js','utf8');
// reuse helpers by evaluating the top part
const head=src.slice(0,src.indexOf('(async()=>{'));
eval(head+`
(async()=>{
  const gas=makeGas();const w=await boot(gas);const app=vm_(w);await sleep(500);
  // edit
  const d=app.devices[0];app.editDevice(d);app.form.model='EDIT';app.saveDevice();await sleep(300);
  ok(app.devices.length===2&&app.devices.find(x=>x.id===d.id).model==='EDIT','düzenleme (kopya oluşmadı)');
  ok(gas.rows().some(r=>r[4]==='EDIT'),'düzenleme Sheet\\'e yazıldı');
  // pin change
  app.newPin='4321';app.newPin2='4321';await app.changePin();await sleep(100);
  ok(app.pinMsgOk&&gas.props.ACCESS_PIN==='4321','PIN değiştirme');
  app.newPin='12';app.newPin2='12';await app.changePin();ok(/en az 4/.test(app.pinMsg),'kısa PIN reddi');
  // offline queue
  const orig=w.google.script.run;
  w.google.script.run=new Proxy({},{get(_,n){if(n==='withSuccessHandler')return ()=>w.google.script.run;if(n==='withFailureHandler')return f=>new Proxy({},{get:()=>()=>setTimeout(()=>f({message:'network'}),5)});return ()=>{}}});
  app.openModal('REPAIR');Object.assign(app.form,{brand:'Offline',model:'X'});app.saveDevice();await sleep(300);
  ok(app.pending.length>=1&&app.devices.some(x=>x.brand==='Offline'),'çevrimdışı kayıt kuyruğa alındı, yerelde duruyor');
  w.google.script.run=orig;await app.flushQueue();await sleep(300);
  ok(app.pending.length===0&&gas.rows().some(r=>r[3]==='Offline'),'bağlantı gelince kuyruk buluta gönderildi');
  // delete
  const o=app.devices.find(x=>x.brand==='Offline');app.deleteDevice(o.id);await sleep(300);
  ok(!gas.rows().some(r=>r[3]==='Offline'),'silme Sheet\\'e yansıdı');
  // tab render w/o errors
  for(const t of ['dashboard','repairs','sales','backups']){app.currentTab=t;await sleep(50);}
  ok(w.document.body.textContent.includes('Anlık Görüntüler'),'yedekleme sekmesi render edildi');
  app.openRestoreModal(app.cloudBackups[0]||{id:'x',name:'n'},'merge');await sleep(100);
  ok(/Geri Yükleme Onayı/.test(w.document.body.textContent),'geri yükleme penceresi render');
  console.log(fails?fails+' FAIL':'ALL OK');process.exit(fails?1:0);
})()`);
