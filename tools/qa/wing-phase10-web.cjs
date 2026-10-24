const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','wing-phase10');
const key='flutter.shootingstar.profile.v1';
async function ready(p){for(let i=0;i<80;i++){
 const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());
 if(await p.getByRole('button',{name:'성장',exact:true}).count())break;await p.waitForTimeout(100);
}await p.waitForLoadState('networkidle');}
async function saved(p){return p.evaluate(key=>{let v=localStorage.getItem(key);for(let i=0;i<3&&typeof v==='string';i++)v=JSON.parse(v);return v;},key);}
async function click(p,a,min=48){const b=await reveal(p,a,min);await p.touchscreen.tap(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(150);}
async function archive(p){await click(p,p.getByRole('button',{name:'성장',exact:true}));await p.getByRole('checkbox',{name:'관리',exact:true}).click();await click(p,p.getByRole('button',{name:'보스 전용 장비',exact:true}),64);}
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 fs.mkdirSync(out,{recursive:true});const errors=[];
 try{
  const c=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated smoke"}'}));
  const input=JSON.parse(fs.readFileSync(path.join(__dirname,'evidence','wing-phase4','production-input.json'),'utf8'));
  input.onboarded=true;input.campaignRewardsVersion=1;input.campaignRewards={bossWorlds:[],routes:[]};
  input.bossGearVersion=1;input.bossGear={defeats:[3,...Array(9).fill(0)],claimed:Array(10).fill(0)};
  await c.addInitScript(({key,input})=>{if(!localStorage.getItem(key))localStorage.setItem(key,JSON.stringify(JSON.stringify(input)));},{key,input});
  const p=await c.newPage();p.setDefaultTimeout(10000);
  p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
  await p.goto('http://127.0.0.1:8797/?ui=v10.0.12');await ready(p);
  assert(await p.getByText('v10.0.12',{exact:true}).count());const before=await saved(p);
  await archive(p);await p.screenshot({path:path.join(out,'archive.png')});
  const claim=()=>p.getByRole('button',{name:'잔광 외곽 전용 장비 회수',exact:true});
  for(let i=0;i<2;i++){
   await click(p,claim(),72);assert(await p.getByRole('heading',{name:'보스 장비 회수',exact:true}).count());
   if(i===1)await p.screenshot({path:path.join(out,'reward.png')});
   await click(p,p.getByRole('button',{name:'확인',exact:true}),72);
  }
  assert.equal(await claim().isEnabled(),false);
  let state=await saved(p);assert.equal(state.bossGear.claimed[0],2);
  const pieces=state.content.inventory.filter(g=>g.spec===12||g.spec===13);assert.equal(pieces.length,2);
  assert(pieces.every(g=>g.rank===2&&g.locked));assert.equal(state.credits,before.credits);
  await click(p,p.getByRole('button',{name:'Back',exact:true}));await p.getByRole('checkbox',{name:'보관',exact:true}).click();
  for(const name of ['잔광 수문장 선체','잔광 수문장 추진기']){
   await click(p,p.getByRole('button',{name:new RegExp(`^${name} 희귀`)}),88);
   await click(p,p.getByRole('button',{name:'장착',exact:true}),64);
   await click(p,p.getByRole('button',{name:'장비 상세 닫기',exact:true}));
  }
  state=await saved(p);
  assert.equal(state.content.equippedGear[3],pieces.find(g=>g.spec===12).id);
  assert.equal(state.content.equippedGear[5],pieces.find(g=>g.spec===13).id);
  for(const field of ['armamentCollection','selectedArmament','blueprints','campaignRewards'])assert.deepEqual(state[field],before[field]);
  await p.reload();await ready(p);const reloaded=await saved(p);
  assert.deepEqual(reloaded.bossGear,state.bossGear);assert.deepEqual(reloaded.content.equippedGear,state.content.equippedGear);
  await archive(p);assert((await p.locator('body').ariaSnapshot()).includes('활성: 잔광 외곽 2피스'));
  await p.reload();await ready(p);await click(p,p.getByRole('button',{name:/ · 출격$/}).first(),72);
  await p.getByRole('button',{name:'일시정지',exact:true}).waitFor();await p.getByRole('button',{name:'일시정지',exact:true}).click();
  await click(p,p.getByRole('button',{name:'전투 통계',exact:true}),64);
  await p.getByRole('tab',{name:'현재 빌드',exact:true}).click();
  // Flutter exposes this tab's text as one aggregate semantic group. Read
  // its text and scroll the audited build-item list to its first entry.
  await p.mouse.move(195,400);await p.mouse.wheel(0,-30000);await p.waitForTimeout(200);
  const text=await p.locator('body').ariaSnapshot();assert(text.includes('보스 세트 · 잔광 외곽'));
  await p.screenshot({path:path.join(out,'combat-set.png')});fs.writeFileSync(path.join(out,'combat-set.txt'),text);
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'production-browser.json'),JSON.stringify({version:'v10.0.12',width:390,claims:2,rareProtectedPieces:true,actualInventoryEquip:true,reloadPreserved:true,combatSnapshotSet:true,unrelatedProgressPreserved:true,errors,scope:'Release UI; isolated profile seeded with three earned boss counts. Real claims, equip, storage reload and natural combat entry; no claim of earning those three kills naturally.'},null,2));
  console.log(JSON.stringify({passed:1,errors}));
 }catch(e){for(const c of browser.contexts())for(const p of c.pages()){
  await p.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});
  fs.writeFileSync(path.join(out,'failure.txt'),await p.locator('body').ariaSnapshot().catch(()=>''));
 }throw e;
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
