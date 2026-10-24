const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','wing-phase9');
const key='flutter.shootingstar.profile.v1';
async function ready(p){for(let i=0;i<80;i++){
 const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());
 if(await p.getByRole('button',{name:'성장',exact:true}).count())break;await p.waitForTimeout(100);
}await p.waitForLoadState('networkidle');}
async function saved(p){return p.evaluate(key=>{let v=localStorage.getItem(key);for(let i=0;i<3&&typeof v==='string';i++)v=JSON.parse(v);return v;},key);}
async function click(p,a,min=48){const b=await reveal(p,a,min);await p.touchscreen.tap(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(150);}
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 fs.mkdirSync(out,{recursive:true});const rows=[],errors=[];
 try{
  for(const [width,claimed] of [[320,false],[390,true]]){
   const c=await browser.newContext({viewport:{width,height:width===320?568:844},isMobile:true,hasTouch:true});
   await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated smoke"}'}));
   const input=JSON.parse(fs.readFileSync(path.join(__dirname,'evidence','wing-phase4','production-input.json'),'utf8'));
   input.onboarded=true;input.campaignRewardsVersion=1;input.campaignRewards={bossWorlds:claimed?[0]:[],routes:claimed?[0]:[]};
   await c.addInitScript(({key,input})=>{if(!localStorage.getItem(key))localStorage.setItem(key,JSON.stringify(JSON.stringify(input)));},{key,input});
   const p=await c.newPage();p.setDefaultTimeout(10000);
   p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
   await p.goto('http://127.0.0.1:8797/?ui=v10.0.11');await ready(p);
   assert(await p.getByText('v10.0.11',{exact:true}).count());const before=await saved(p);
   await click(p,p.getByRole('button',{name:'챕터 선택',exact:true}));
   await click(p,p.getByRole('button',{name:/1-1 · 접근 항로/}).first(),88);
   await click(p,p.getByRole('button',{name:'보상 안내',exact:true}),64);
   let text=await p.locator('body').ariaSnapshot();assert(text.includes('보스·항로 보상'));
   await p.screenshot({path:path.join(out,`guide-${width}-first.png`)});
   const seen=new Set();
   for(let i=0;i<16;i++){
    text=await p.locator('body').ariaSnapshot();
    for(const label of ['보스 회수 · 매 처치','세계 첫 보스','항로 완주 · 매 클리어','항로 첫 보너스'])if(text.includes(label))seen.add(label);
    if(claimed&&text.includes('항로 첫 보너스'))assert(text.includes('항로 첫 보너스 · 수령 완료'));
    const next=p.getByRole('button',{name:'다음 페이지',exact:true}).last();
    if(!await next.count()||!await next.isEnabled())break;
    const b=await next.boundingBox();await p.touchscreen.tap(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(100);
   }
   assert.equal(seen.size,4);await p.screenshot({path:path.join(out,`guide-${width}-last.png`)});
   fs.writeFileSync(path.join(out,`guide-${width}.txt`),text);
   const after=await saved(p);
   for(const field of ['credits','blueprints','armamentCollection','selectedArmament','campaignRewards','selectedStage'])assert.deepEqual(after[field],before[field]);
   assert.equal(await p.evaluate(()=>document.documentElement.scrollHeight>innerHeight),false);
   rows.push({width,claimed,fixedPageGuide:true,allRewardSectionsSeen:true,openingGuidePaysNothing:true,ownershipAndLedgerPreserved:true});
   await c.close();
  }
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'production-browser.json'),JSON.stringify({version:'v10.0.11',rows,errors,scope:'Production release; isolated claimed/unclaimed profiles; real reward guide navigation only. Actual settlement and result receipt separately tested in model/widget tests.'},null,2));
  console.log(JSON.stringify({passed:rows.length,errors}));
 }catch(e){for(const c of browser.contexts())for(const p of c.pages()){
  await p.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});
  fs.writeFileSync(path.join(out,'failure.txt'),await p.locator('body').ariaSnapshot().catch(()=>''));
 }throw e;
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
