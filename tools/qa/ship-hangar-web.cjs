const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','ship-hangar');
const key='flutter.shootingstar.profile.v1';
async function ready(p){for(let i=0;i<80;i++){
 const placeholder=p.locator('flt-semantics-placeholder');if(await placeholder.count())await placeholder.evaluate(e=>e.click());
 if(await p.getByRole('button',{name:'성장',exact:true}).count())break;await p.waitForTimeout(100);
}await p.waitForLoadState('networkidle');}
async function saved(p){return p.evaluate(key=>{let v=localStorage.getItem(key);for(let i=0;i<3&&typeof v==='string';i++)v=JSON.parse(v);return v;},key);}
async function click(p,name,min=48){const a=p.getByRole('button',{name,exact:true}).first();const b=await reveal(p,a,min);await p.touchscreen.tap(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(150);}
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 fs.mkdirSync(out,{recursive:true});const rows=[],errors=[];
 try{
  for(const width of [320,390]){
   const c=await browser.newContext({viewport:{width,height:width===320?568:844},isMobile:true,hasTouch:true});
   await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated smoke"}'}));
   const input=JSON.parse(fs.readFileSync(path.join(__dirname,'evidence','wing-phase4','production-input.json'),'utf8'));
   input.onboarded=true;input.credits=1000;
   await c.addInitScript(({key,input})=>{if(!localStorage.getItem(key))localStorage.setItem(key,JSON.stringify(JSON.stringify(input)));},{key,input});
   const p=await c.newPage();p.setDefaultTimeout(10000);
   p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
   await p.goto('http://127.0.0.1:8797/?ui=v10.0.9');await ready(p);
   assert(await p.getByText('v10.0.9',{exact:true}).count());
   const before=await saved(p);
   await click(p,'오로라 · 기체 선택');
   await click(p,'벡터 200 C 해금·선택',72);
   let state=await saved(p);assert.equal(state.selectedShip,1);assert.equal(state.credits,800);assert(state.unlockedShips.includes(1));
   await click(p,'오로라 선택',72);await click(p,'벡터 선택',72);
   assert.equal((await saved(p)).credits,800);
   await click(p,'모노리스 450 C 해금·선택',72);
   state=await saved(p);assert.equal(state.selectedShip,2);assert.equal(state.credits,350);
   await p.screenshot({path:path.join(out,`selection-${width}.png`)});
   fs.writeFileSync(path.join(out,`selection-${width}.txt`),await p.locator('body').ariaSnapshot());
   await p.reload();await ready(p);
   state=await saved(p);assert.equal(state.selectedShip,2);assert.equal(state.credits,350);
   for(const field of ['armamentCollection','selectedArmament','blueprints'])assert.deepEqual(state[field],before[field]);
   assert(await p.getByRole('button',{name:'모노리스 · 기체 선택',exact:true}).count());
   await click(p,'성장');await p.getByRole('checkbox',{name:'관리',exact:true}).click();
   await click(p,'기체 선택',64);
   assert((await p.locator('body').ariaSnapshot()).includes('장착: 모노리스 · 350 C'));
   assert.equal(await p.evaluate(()=>document.documentElement.scrollHeight>innerHeight),false);
   rows.push({width,lobbyEntry:true,growthEntry:true,vectorUnlockCost:200,monolithUnlockCost:450,reselectionFree:true,reloadPreserved:true,unrelatedProgressPreserved:true});
   await c.close();
  }
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'production-browser.json'),JSON.stringify({version:'v10.0.9',rows,errors,scope:'Production release; isolated local profiles, real UI clicks and storage reload'},null,2));
  console.log(JSON.stringify({passed:rows.length,errors}));
 }catch(e){for(const c of browser.contexts())for(const p of c.pages()){
  await p.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});
  fs.writeFileSync(path.join(out,'failure.txt'),await p.locator('body').ariaSnapshot().catch(()=>''));
 }throw e;
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
