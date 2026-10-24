const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const out=path.join(__dirname,'evidence','wing-phase8');
const key='flutter.shootingstar.profile.v1';
async function ready(p){for(let i=0;i<80;i++){
 const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());
 if(await p.getByRole('button',{name:'성장',exact:true}).count())break;await p.waitForTimeout(100);
}await p.waitForLoadState('networkidle');}
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 fs.mkdirSync(out,{recursive:true});const rows=[],errors=[];
 try{
  for(const [world,label] of [[4,'포격 예고 · 표식 이탈'],[5,'기뢰 예고 · 열린 출구'],[7,'쌍열 예고 · 중앙 통로']]){
   const c=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
   await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated smoke"}'}));
   const input=JSON.parse(fs.readFileSync(path.join(__dirname,'evidence','wing-phase4','production-input.json'),'utf8'));
   input.onboarded=true;input.hullLevel=5;input.armamentCollection={pulse:0};input.selectedStage=world*10;
   input.selectedShip=2;input.unlockedShips=[0,2];input.clearedStages=Array.from({length:world*10},(_,i)=>i);
   for(const id of input.content.equippedGear.slice(3))input.content.inventory.find(g=>g.id===id).level=20;
   await c.addInitScript(({key,input})=>{if(!localStorage.getItem(key))localStorage.setItem(key,JSON.stringify(JSON.stringify(input)));},{key,input});
   const p=await c.newPage();p.setDefaultTimeout(10000);
   p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
   await p.goto('http://127.0.0.1:8797/?ui=v10.0.10');await ready(p);
   assert(await p.getByText('v10.0.10',{exact:true}).count());
   await p.getByRole('button',{name:'45초 훈련',exact:true}).click();
   await p.getByRole('button',{name:'일시정지',exact:true}).waitFor();
   await p.clock.install();await p.clock.pauseAt(new Date(Date.now()+50));
   let warning=false;const phases=new Set();
   for(let i=0;i<360;i++){
    await p.clock.runFor(100);
    const text=await p.locator('body').ariaSnapshot();
    for(const n of [1,2,3])if(text.includes(`보스 · ${n}단계`))phases.add(n);
    if(!warning&&text.includes(label)){
     warning=true;await p.screenshot({path:path.join(out,`world-${world+1}-warning.png`)});
     fs.writeFileSync(path.join(out,`world-${world+1}-warning.txt`),text);
    }
    if(warning&&phases.size===3)break;
    // Actual growth cards have a large painted region; all ordinary controls
    // are shorter. Choose a visible card through a pointer if XP pauses play.
    if(text.includes('성장 선택')||text.includes('특화 선택')){
     for(const button of await p.getByRole('button').all()){
      const box=await button.boundingBox();
      if(box&&box.height>=200&&box.y>=0&&box.y+box.height<=844){await p.touchscreen.tap(box.x+box.width/2,box.y+box.height/2);await p.clock.runFor(50);break;}
     }
    }
    if(await p.getByRole('button',{name:'다시 출격',exact:true}).count())break;
   }
   assert(warning,`World ${world+1} must naturally display ${label}`);
   rows.push({world:world+1,warning:label,naturalBoss:true,training:true,observedPhases:[...phases],width:390,isolatedDefensiveProfile:true});
   await c.close();
  }
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'production-browser.json'),JSON.stringify({version:'v10.0.10',rows,errors,scope:'Production training entrypoint, natural 29-second boss, isolated defensive profile and virtual waiting; no runtime injection; campaign phase gates separately engine-tested'},null,2));
  console.log(JSON.stringify({passed:rows.length,errors}));
 }catch(e){for(const c of browser.contexts())for(const p of c.pages()){
  await p.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});
  fs.writeFileSync(path.join(out,'failure.txt'),await p.locator('body').ariaSnapshot().catch(()=>''));
 }throw e;
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
