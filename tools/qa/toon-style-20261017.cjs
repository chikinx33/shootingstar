// Local, isolated guest QA. Production and reference-game services are blocked.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const out=path.join(__dirname,'evidence','toon-style-20261017');
const key='flutter.shootingstar.profile.v1';
const base=process.env.SURVIVOR_STYLE_URL || 'http://127.0.0.1:8797';
const fixtures=process.env.SURVIVOR_FIXTURE_URL || 'http://127.0.0.1:8798';
fs.mkdirSync(out,{recursive:true});

(async()=>{
 const browser=await chromium.launch({headless:true,
  executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const errors=[],rows=[],loadedGeneratedAssets=new Set();
 async function open(url,width,height){
  const context=await browser.newContext({viewport:{width,height},isMobile:width<500,hasTouch:true});
  const page=await context.newPage();
  page.on('pageerror',e=>errors.push(e.message));
  page.on('response',r=>{if(r.url().includes('/art/toon_v7/')&&r.status()===200)loadedGeneratedAssets.add(new URL(r.url()).pathname.split('/').pop());});
  page.on('console',m=>{if(m.text().includes('EXCEPTION CAUGHT') || m.text().includes('overflowed by'))errors.push(m.text());});
  await context.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"QA isolated guest"}'}));
  await context.route('https://**',r=>r.abort());
  await page.goto(url);await page.waitForTimeout(1100);await semantics(page);
  return {context,page};
 }
 async function semantics(page){
  if(await page.locator('flt-semantics-placeholder').count())
   await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  await page.waitForTimeout(180);
 }
 async function shot(page,name){await page.screenshot({path:path.join(out,name+'.png')});}
 async function saved(page){return page.evaluate(key=>{
  let value=localStorage.getItem(key);for(let i=0;i<3 && typeof value==='string';i++)value=JSON.parse(value);return value;
 },key);}
 try {
  for(const [width,height] of [[320,568],[360,640],[390,844],[430,932]]) {
   console.log("mobile",width);
   const {context,page}=await open(base,width,height);
   const launch=page.getByRole('button',{name:'잔광 외곽 1-1 · 출격',exact:true});
   const box=await launch.boundingBox();assert(box && box.y>=0 && box.y+box.height<height-64);
   await shot(page,`home-${width}x${height}`);
   await page.getByText('성장',{exact:true}).click();await page.waitForTimeout(250);
   await page.getByRole('button',{name:'고급 장비 성장 · 정련·융합',exact:true}).waitFor({state:'visible'});
   await shot(page,`equipment-${width}x${height}`);
   await page.mouse.move(width*.5,height*.65);await page.mouse.wheel(0,440);await page.waitForTimeout(250);await shot(page,`inventory-${width}x${height}`);
   await page.getByText('보급',{exact:true}).last().click();await page.waitForTimeout(250);
   await page.getByRole('button',{name:'장비 보급 열기',exact:true}).click();await page.waitForTimeout(250);
   const state=await saved(page);assert.equal(state.content.gearKeys,0);assert.equal(state.content.inventory.length,7);
   await shot(page,`supply-${width}x${height}`);
   await page.reload();await page.waitForTimeout(900);await semantics(page);
   const restored=await saved(page);assert.deepEqual(restored.content.inventory,state.content.inventory);
   assert.equal(restored.content.gearKeys,0);assert.equal(restored.credits,state.credits);
   rows.push({name:`mobile-${width}x${height}`,launchVisible:true,supplyTicketSpentOnce:true,reloadPreserved:true});
   await context.close();
  }
  {
   const {context,page}=await open(base,390,844);
   for(const [label,name] of [['격납고','hangar'],['도전','challenges'],['진화','talents']]){
    await page.getByRole('button',{name:label,exact:true}).first().click();await page.waitForTimeout(250);await shot(page,name);
   }
   await page.getByText('성장',{exact:true}).click();await page.waitForTimeout(250);
   for(const [label,name] of [['펫','pets'],['테크','tech'],['시즌','season']]){
    await page.getByRole('checkbox',{name:label,exact:true}).click();await page.waitForTimeout(250);await shot(page,name);
   }
   await page.getByRole('button',{name:'설정',exact:true}).click();await page.waitForTimeout(250);await shot(page,'settings');
   await context.close();rows.push({name:'all-main-menus',screens:7});
  }
  {
   const {context,page}=await open(base,1280,900);await shot(page,'desktop-portrait');
   await context.close();rows.push({name:'desktop-1280x900'});
  }
  if(!process.argv.includes('--menus-only')) {
   for(const [width,height] of [[320,568],[390,844]]){
    const {context,page}=await open(fixtures+'/?scene=choices',width,height);
    const choice=page.getByRole('button',{name:/^추적 로켓 /});
    assert(await choice.count());await shot(page,`choices-${width}x${height}`);
    await choice.click();await page.waitForTimeout(350);
    assert.equal(await choice.count(),0);await shot(page,`battle-${width}x${height}`);
    await page.getByRole('button',{name:'일시정지',exact:true}).click();await page.waitForTimeout(200);
    await shot(page,`pause-${width}x${height}`);
    await page.getByRole('button',{name:'귀환 · 현재 보상 정산',exact:true}).click();await page.waitForTimeout(300);
    await shot(page,`result-${width}x${height}`);
    rows.push({name:`choices-battle-pause-result-${width}`,choiceApplied:true});await context.close();
   }
   for(let world=0;world<10;world++){
    console.log("world",world+1);
    const {context,page}=await open(fixtures+'/?scene=boss&stage='+world*10+'&ship='+world%3,390,844);
    await page.waitForTimeout(500);await shot(page,'world-boss-'+(world+1));await context.close();
   }
   rows.push({name:'ten-world-boss-fixtures',screens:10});
   const {context,page}=await open(fixtures+'/?scene=stress',390,844);
   const performance=await page.evaluate(()=>new Promise(resolve=>{
    const times=[];let previous=performance.now(),start=previous;
    function frame(now){times.push(now-previous);previous=now;
     if(now-start<2500)requestAnimationFrame(frame);else{
      times.sort((a,b)=>a-b);resolve({frames:times.length,p50:times[Math.floor(times.length*.5)],p95:times[Math.floor(times.length*.95)]});
     }}requestAnimationFrame(frame);
   }));
   await shot(page,'stress');rows.push({name:'450-enemy-fixture',...performance});await context.close();
  }
  assert.deepEqual(errors,[]);
  assert.equal(loadedGeneratedAssets.size,9);
  fs.writeFileSync(path.join(out,'browser-result.json'),JSON.stringify({base,fixtures,rows,errors,
   generatedAssets:[...loadedGeneratedAssets],scope:'isolated local browser guests; reference APK never executed; fixtures use high hull and injected entities, not balance/survival proof'},null,2));
  console.log(JSON.stringify({passed:rows.length,errors,generatedAssets:[...loadedGeneratedAssets],rows},null,2));
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
