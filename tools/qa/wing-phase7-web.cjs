const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','wing-phase7');
const key='flutter.shootingstar.profile.v1';
async function saved(p){return p.evaluate(key=>{let v=localStorage.getItem(key);for(let i=0;i<3&&typeof v==='string';i++)v=JSON.parse(v);return v;},key);}
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 fs.mkdirSync(out,{recursive:true});const rows=[],errors=[];
 try{
  for(const [stage,route,expected] of [[7,'장갑',['방패 가동','방패 재정비']],[6,'추격',['항로 고정','직선 돌진']]]){
   const c=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
   await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated smoke"}'}));
   const input=JSON.parse(fs.readFileSync(path.join(__dirname,'evidence','wing-phase4','production-input.json'),'utf8'));
   input.onboarded=true;input.hullLevel=5;input.armamentCollection={pulse:4};input.selectedStage=stage;
   input.clearedStages=Array.from({length:stage},(_,i)=>i);
   for(const id of input.content.equippedGear.slice(3))input.content.inventory.find(g=>g.id===id).level=20;
   await c.addInitScript(({key,input})=>{if(!localStorage.getItem(key))localStorage.setItem(key,JSON.stringify(JSON.stringify(input)));},{key,input});
   const p=await c.newPage();p.setDefaultTimeout(12000);
   p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
   await p.goto('http://127.0.0.1:8797/?ui=v10.0.8');
   for(let i=0;i<80;i++){
    const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());
    if(await p.getByRole('button',{name:'성장',exact:true}).count())break;await p.waitForTimeout(100);
   }
   await p.waitForLoadState('networkidle');assert(await p.getByText('v10.0.8',{exact:true}).count());
   const before=await saved(p);assert.equal(before.selectedStage,stage);
   await p.getByRole('button',{name:/ · 출격$/}).first().click();
   await p.getByRole('button',{name:'일시정지',exact:true}).waitFor();
   await p.clock.install();await p.clock.pauseAt(new Date(Date.now()+50));
   await p.clock.runFor(100);
   assert((await p.locator('body').ariaSnapshot()).includes(`${route} · 정찰 교전`));
   const seen=new Set();
   for(let i=0;i<60;i++){
    await p.clock.runFor(500);
    const focus=p.getByRole('button',{name:/^집속 펄스/});
    if(await focus.count()){
     const box=await reveal(p,focus,88);await p.touchscreen.tap(box.x+box.width/2,box.y+box.height/2);await p.clock.runFor(50);
    }
    const text=await p.locator('body').ariaSnapshot();
    for(const label of expected)if(!seen.has(label)&&text.includes(`편대 · ${label}`)){
     seen.add(label);await p.screenshot({path:path.join(out,`route-${stage+1}-${seen.size}.png`)});
     fs.writeFileSync(path.join(out,`route-${stage+1}-${seen.size}.txt`),text);
    }
    if(seen.size===2)break;
    if(await p.getByRole('button',{name:'다시 출격',exact:true}).count())break;
   }
   assert.equal(seen.size,2,`Route ${stage+1} must naturally show ${expected}`);
   const bounds=await p.getByRole('button',{name:'일시정지',exact:true}).boundingBox();
   assert(bounds&&bounds.y>=0&&bounds.y+bounds.height<=844);
   assert.equal(await p.evaluate(()=>document.documentElement.scrollHeight>innerHeight),false);
   await p.mouse.wheel(0,300);assert.deepEqual(await p.getByRole('button',{name:'일시정지',exact:true}).boundingBox(),bounds);
   const after=await saved(p);
   for(const field of ['armamentCollection','selectedArmament','selectedStage','credits','blueprints'])assert.deepEqual(after[field],before[field]);
   rows.push({stage:stage+1,world:1,route,naturalStates:[...seen],width:390,height:844,productionEntrypoint:true,isolatedProfile:true,fixedViewport:true,ownershipAndResourcesPreserved:true});
   await c.close();
  }
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'production-browser.json'),JSON.stringify({version:'v10.0.8',rows,errors,scope:'Release entrypoint; isolated unlocked-route defensive profile, virtual waiting; no runtime enemy/time injection or survival completion claim'},null,2));
  console.log(JSON.stringify({passed:rows.length,errors}));
 }catch(e){for(const c of browser.contexts())for(const p of c.pages()){
  await p.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});
  fs.writeFileSync(path.join(out,'failure.txt'),await p.locator('body').ariaSnapshot().catch(()=>''));
 }throw e;
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
