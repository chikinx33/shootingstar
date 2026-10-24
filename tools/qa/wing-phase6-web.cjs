const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','wing-phase6');
const key='flutter.shootingstar.profile.v1';
const production=process.argv.includes('--production');
const saved=p=>p.evaluate(key=>{let v=localStorage.getItem(key);for(let i=0;i<3&&typeof v==='string';i++)v=JSON.parse(v);return v;},key);
async function ready(p,clock){for(let i=0;i<100;i++){
 const placeholder=p.locator('flt-semantics-placeholder');if(await placeholder.count())await placeholder.evaluate(e=>e.click());
 if(await p.getByRole('button',{name:'일시정지',exact:true}).count()||await p.getByRole('button',{name:'성장',exact:true}).count())break;
 if(clock)await p.clock.runFor(40);await p.waitForTimeout(100);
}await p.waitForLoadState('networkidle');}
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 fs.mkdirSync(out,{recursive:true});const rows=[],errors=[];
 try{
  const cases=production?[[390,844,1,'natural']]:[
   [320,568,1,'bulwark'],[320,568,1.3,'assault'],[360,640,1,'assault'],[360,640,1.3,'bulwark'],
   [390,844,1,'bulwark'],[390,844,1.3,'assault'],[430,932,1,'assault'],[430,932,1.3,'bulwark']];
  for(const [width,height,scale,formation] of cases){
   const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
   await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated smoke"}'}));
   if(production){
    const input=JSON.parse(fs.readFileSync(path.join(__dirname,'evidence','wing-phase4','production-input.json'),'utf8'));
    input.onboarded=true;input.hullLevel=5;input.armamentCollection={pulse:4};
    for(const id of input.content.equippedGear.slice(3))input.content.inventory.find(g=>g.id===id).level=20;
    await c.addInitScript(({key,input})=>{if(!localStorage.getItem(key))localStorage.setItem(key,JSON.stringify(JSON.stringify(input)));},{key,input});
   }
   const p=await c.newPage();p.setDefaultTimeout(12000);
   p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
   if(!production){await p.clock.install();await p.clock.pauseAt(new Date(Date.now()+50));}
   await p.goto(production?'http://127.0.0.1:8797/?ui=v10.0.7':`http://127.0.0.1:8804/?scene=wing-phase6&formation=${formation}&textScale=${scale}`);
   await ready(p,!production);
   const tag=production?'production-390':`${formation}-${width}-scale-${scale}`;
   if(production){
    assert(await p.getByText('v10.0.7',{exact:true}).count());
    const before=await saved(p);await p.getByRole('button',{name:/ · 출격$/}).first().click();
    await p.getByRole('button',{name:'일시정지',exact:true}).waitFor();
    await p.clock.install();await p.clock.pauseAt(new Date(Date.now()+50));
    const seen=new Set();
    for(let i=0;i<560;i++){
     await p.clock.runFor(100);
     const focus=p.getByRole('button',{name:/^집속 펄스/});
     if(await focus.count()){
      const box=await reveal(p,focus,88);await p.touchscreen.tap(box.x+box.width/2,box.y+box.height/2);await p.clock.runFor(50);
     }
     const text=await p.locator('body').ariaSnapshot();
     for(const [state,label] of [['assault-tell','돌입 편대 · 항로 고정'],['assault-charge','돌입 편대 · 직선 돌진'],['bulwark-active','방패·중장 편대 · 방패 가동'],['bulwark-vent','방패·중장 편대 · 방패 재정비']]){
      if(!seen.has(state)&&text.includes(label)){
       seen.add(state);await p.screenshot({path:path.join(out,`${tag}-${state}.png`)});
       fs.writeFileSync(path.join(out,`${tag}-${state}.txt`),text);
      }
     }
     if(seen.size===4)break;
     if(await p.getByRole('button',{name:'다시 출격',exact:true}).count())break;
    }
    assert.equal(seen.size,4,'Natural run must display both warning/charge and guard/opening');
    const after=await saved(p);assert.deepEqual(after.armamentCollection,before.armamentCollection);assert.equal(after.selectedArmament,before.selectedArmament);
    rows.push({width,height,textScale:scale,productionEntrypoint:true,naturalStates:[...seen],isolatedDefensiveLoadoutFixture:true,permanentOwnershipPreserved:true});
   }else{
    await p.clock.runFor(40);
    let state=await p.locator('body').ariaSnapshot();
    assert(state.includes(formation==='assault'?'돌입 편대 · 항로 고정':'방패·중장 편대 · 방패 가동'));
    await p.screenshot({path:path.join(out,`${tag}-warning.png`)});
    const pause=p.getByRole('button',{name:'일시정지',exact:true}),bounds=await pause.boundingBox();
    assert(bounds&&bounds.y>=0&&bounds.y+bounds.height<=height);
    assert.equal(await p.evaluate(()=>document.documentElement.scrollHeight>innerHeight),false);
    await p.mouse.wheel(0,300);assert.deepEqual(await pause.boundingBox(),bounds);
    await p.clock.runFor(formation==='assault'?1100:1500);
    state=await p.locator('body').ariaSnapshot();
    assert(state.includes(formation==='assault'?'돌입 편대 · 직선 돌진':'방패·중장 편대 · 방패 재정비'));
    await p.screenshot({path:path.join(out,`${tag}-active.png`)});
    fs.writeFileSync(path.join(out,`${tag}.txt`),state);
    rows.push({width,height,textScale:scale,formation,warningAndActiveStates:true,fixedViewport:true,productionEntrypoint:false,posedVisualFixture:true});
   }
   await c.close();
  }
  assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,production?'production-browser.json':'browser-matrix.json'),JSON.stringify({version:'v10.0.7',rows,errors,scope:production?'Production entrypoint; defensive profile input only; natural encounter timing, virtual waiting, no runtime injection':'Current-source local visual fixture, natural scheduler advanced to encounter; actual Flutter TextScaler'},null,2));
  console.log(JSON.stringify({passed:rows.length,production,errors}));
 }catch(e){for(const c of browser.contexts())for(const p of c.pages()){
  await p.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});
  fs.writeFileSync(path.join(out,'failure.txt'),await p.locator('body').ariaSnapshot().catch(()=>''));
 }throw e;
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
