const {chromium}=require('playwright'),fs=require('fs'),path=require('path'),assert=require('assert'),crypto=require('crypto');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','completion-v30');fs.mkdirSync(out,{recursive:true});
const button=(p,n)=>p.getByRole('button',{name:new RegExp('^'+n.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+'(?:$|[ ,·\\n])')}).last();
async function ready(p,n){for(let i=0;i<150;i++){const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());if(await button(p,n).count())return;await p.waitForTimeout(100);}throw Error('Not ready '+n);}
async function click(p,n){const b=await reveal(p,button(p,n));await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(180);}
async function fixed(p,locator){assert.equal(await p.evaluate(()=>document.documentElement.scrollHeight>innerHeight),false);const b=await locator.boundingBox();await p.mouse.wheel(0,500);assert.deepEqual(await locator.boundingBox(),b);const touch=await p.context().newCDPSession(p);await touch.send('Input.synthesizeScrollGesture',{x:p.viewportSize().width/2,y:300,yDistance:-160,speed:600,gestureSourceType:'touch'});assert.deepEqual(await locator.boundingBox(),b);await touch.detach();}
async function readProfile(p){return p.evaluate(()=>{let v=JSON.parse(localStorage.getItem('flutter.shootingstar.profile.v1'));if(typeof v==='string')v=JSON.parse(v);return v;});}
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'}),matrix=[],errors=[];
 try{
  for(const width of [320,360,390,430])for(const scale of [1,1.3]){
   const c=await browser.newContext({viewport:{width,height:568},isMobile:true,hasTouch:true,acceptDownloads:true,permissions:['clipboard-read','clipboard-write']});
   await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.abort());
   const p=await c.newPage();p.setDefaultTimeout(12000);p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
   await p.goto(process.env.QA_URL+'/?scale='+scale);await ready(p,'설정');await click(p,'설정');await ready(p,'조작');
   const settings=button(p,'조작');await fixed(p,settings);await p.screenshot({path:path.join(out,`settings-${width}-${scale}.png`)});
   await click(p,'조작');await p.getByText('조작·음향',{exact:true}).waitFor();await click(p,'짧게 움직이기');await click(p,'왼쪽');
   const defaults=button(p,'조작 기본값 복원');await reveal(p,defaults);await fixed(p,defaults);
   await p.screenshot({path:path.join(out,`controls-${width}-${scale}.png`)});
   const stored=await readProfile(p);assert.equal(stored.controls.sensitivity,2);assert.equal(stored.controls.leftActions,true);
   await p.goto(process.env.QA_URL+'/?mode=backup&scale='+scale);await ready(p,'백업 파일 저장');
   const downloadEvent=p.waitForEvent('download');await click(p,'백업 파일 저장');const download=await downloadEvent;
   const file=path.join(out,`backup-${width}-${scale}.json`);await download.saveAs(file);
   const backup=JSON.parse(fs.readFileSync(file,'utf8'));assert.equal(backup.format,'shootingstar.progress.backup');assert.equal(crypto.createHash('sha256').update(backup.payload).digest('hex'),backup.sha256);
   assert(!backup.payload.includes('_battle'));assert(!backup.payload.includes('guildNickname'));assert.equal(JSON.parse(backup.payload).progress.credits,150);
   const body=JSON.parse(backup.payload);body.progress.credits=321;backup.payload=JSON.stringify(body);backup.sha256=crypto.createHash('sha256').update(backup.payload).digest('hex');
   const chooserEvent=p.waitForEvent('filechooser');await click(p,'백업 파일 선택');const chooser=await chooserEvent;await chooser.setFiles({name:'verified-progress.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(backup))});
   await p.waitForTimeout(250);await click(p,'백업 내용으로 복원');await click(p,'취소');
   let current=await readProfile(p);assert.equal(current.credits,150,'cancel must preserve current progress');
   await click(p,'백업 내용으로 복원');await click(p,'이 진행으로 복원');await p.waitForTimeout(200);
   current=await readProfile(p);assert.equal(current.credits,321);
   const undo=button(p,'복원 전 진행으로 되돌리기');await reveal(p,undo);await fixed(p,undo);await p.screenshot({path:path.join(out,`backup-restored-${width}-${scale}.png`)});
   await click(p,'복원 전 진행으로 되돌리기');await click(p,'이 진행으로 복원');await p.waitForTimeout(200);
   current=await readProfile(p);assert.equal(current.credits,150);
   matrix.push({width,scale,settingsFixed:true,controlsPersist:true,realDownloadAndPicker:true,cancelPreserved:true,restoreAndUndo:true});console.log('matrix',width,scale);await c.close();
  }
  // Normal battle, real pause route and mirrored ability placement.
  const c=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.abort());
  const p=await c.newPage();p.setDefaultTimeout(12000);await p.goto(process.env.QA_URL+'/?mode=battle');await ready(p,'일시정지');await click(p,'일시정지');await click(p,'조작·음향 설정');await click(p,'왼쪽');await click(p,'Back');await click(p,'계속 비행');
  const ultimate=p.getByRole('button',{name:/^궁극기 충전/});await ultimate.waitFor();const box=await ultimate.boundingBox();assert(box.x<25,'ultimate should be on the left');await p.screenshot({path:path.join(out,'battle-left-actions.png')});await c.close();
  assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify({version:'v10.0.30',scope:'isolated origins, real Flutter widgets/file transfer; no native build',matrix,battlePauseAndMirror:true,errors},null,2));
 }catch(error){fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.message,matrix,errors},null,2));throw error;}
 finally{await browser.close();}
})().catch(error=>{console.error(error);process.exit(1);});
