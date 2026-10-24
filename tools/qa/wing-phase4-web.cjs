// Isolated guests only. Fixture currencies exercise spending, never user saves.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','wing-phase4');
const storageKey='flutter.shootingstar.profile.v1';
const saved=p=>p.evaluate(key=>{
 let value=localStorage.getItem(key);
 for(let i=0;i<3&&typeof value==='string';i++)value=JSON.parse(value);
 return value;
},storageKey);
const waitLevel=(p,level)=>p.waitForFunction(({key,level})=>{
 let value=localStorage.getItem(key);
 for(let i=0;i<3&&typeof value==='string';i++)value=JSON.parse(value);
 return value?.armamentCollection?.kunai===level;
},{key:storageKey,level});
async function click(p,name,height=64) {
 const button=p.getByRole('button',{name,exact:true});
 const b=await reveal(p,button,height);
 assert(b&&b.height>=height-.3);assert(await button.isEnabled());
 await p.touchscreen.tap(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(130);
 return b;
}
async function ready(p) {
 for(let i=0;i<75;i++) {
  const placeholder=p.locator('flt-semantics-placeholder');
  if(await placeholder.count())await placeholder.evaluate(e=>e.click());
  if((await p.getByRole('button',{name:'펄스 주포 소유·성장 상세',exact:true}).count()) || (await p.getByRole('button',{name:'성장',exact:true}).count()))break;
  await p.waitForTimeout(100);
 }
 await p.waitForLoadState('networkidle');
}
async function main(){
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const rows=[],errors=[];fs.mkdirSync(out,{recursive:true});
 const production=process.argv.includes('--production');
 try {
 for(const [width,height,scale] of (production?[[390,844,1]]:[[320,568,1],[320,568,1.3],[360,640,1],[360,640,1.3],[390,844,1],[390,844,1.3],[430,932,1],[430,932,1.3]])) {
  const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
  await c.route('https://**',r=>r.abort());
  await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated smoke"}'}));
  const p=await c.newPage();p.setDefaultTimeout(12000);
  p.on('pageerror',e=>errors.push(e.message));
  p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
  const tag=production?'production-390':`fixture-${width}-scale-${scale}`;
  if(production) {
   // Prepared by the real current fixture UI in a separate guest context.
   // Only currency is an input fixture; all unlock/upgrade/equip actions are UI.
   const input=JSON.parse(fs.readFileSync(path.join(out,'production-input.json'),'utf8'));
   await c.addInitScript(({key,input})=>{if(!localStorage.getItem(key))localStorage.setItem(key,JSON.stringify(JSON.stringify(input)));},{key:storageKey,input});
   await p.goto('http://127.0.0.1:8797/?ui=v10.0.5');await ready(p);
   assert(await p.getByText('v10.0.5',{exact:true}).count());
   await click(p,'성장',48);
   await p.getByRole('checkbox',{name:'관리',exact:true}).click();
   await click(p,'주무기 소유·성장');
  } else {
   await p.goto(`http://127.0.0.1:8804/?scene=armaments&textScale=${scale}`);await ready(p);
  }
  await click(p,'유도 침 소유·성장 상세');
  await click(p,'유도 침 해금',72);
  await click(p,'유도 침 장착',72);
  const b=await click(p,'유도 침 강화');
  await waitLevel(p,1);
  let state=await saved(p);assert.equal(state.selectedArmament,1);
  assert.equal(state.credits,1580);assert.equal(state.blueprints,16);
  await p.screenshot({path:path.join(out,`${tag}-upgraded.png`)});
  const upgrade=p.getByRole('button',{name:'유도 침 강화',exact:true});
  await reveal(p,upgrade,64);const before=await upgrade.boundingBox();
  await p.mouse.wheel(0,350);await p.waitForTimeout(120);
  assert.deepEqual(await upgrade.boundingBox(),before,'detail may not scroll with wheel');
  const session=await c.newCDPSession(p);
  await session.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:25,y:height-140}]});
  await session.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:25,y:height-280}]});
  await session.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await p.waitForTimeout(150);
  assert.deepEqual(await upgrade.boundingBox(),before,'detail may not scroll with touch');
  await click(p,'유도 침 강화 초기화');
  await click(p,'재료 반환 · 초기화',72);
  await waitLevel(p,0);
  state=await saved(p);assert.equal(state.credits,1700);assert.equal(state.blueprints,17);assert.equal(state.selectedArmament,1);
  await click(p,'유도 침 강화');await click(p,'닫기',48);
  const completed=await saved(p);assert.equal(completed.armamentCollection.kunai,1);
  if(!production && width===390 && scale===1) {
   const input=structuredClone(completed);input.credits=2000;input.blueprints=20;input.selectedArmament=0;input.armamentCollection={pulse:0};input.onboarded=true;
   fs.writeFileSync(path.join(out,'production-input.json'),JSON.stringify(input,null,2));
  }
  await p.reload();await ready(p);
  const reloaded=await saved(p);
  assert.equal(reloaded.armamentCollection.kunai,1);assert.equal(reloaded.selectedArmament,1);
  if(production) {
   assert.equal(reloaded.credits,1580);assert.equal(reloaded.blueprints,16);
   await p.getByRole('button',{name:/ · 출격$/}).first().click();
   await p.getByRole('button',{name:'일시정지',exact:true}).waitFor();
   await click(p,'일시정지',48);await click(p,'전투 통계');
   await p.getByRole('tab',{name:'현재 빌드',exact:true}).click();await p.waitForTimeout(350);
   assert(await p.getByText(/유도 침[\s\S]*영구 강화 1\/10 · 주무기 피해 \+2%/).count());
   assert(await p.getByText(/R 연사 0\/5 · P 출력 0\/5/).count());
   await p.screenshot({path:path.join(out,'production-battle-build.png')});
  } else {
   await click(p,'유도 침 소유·성장 상세');
   await p.screenshot({path:path.join(out,`${tag}-reload.png`)});
  }
  rows.push({width,height,textScale:scale,productionEntrypoint:production,isolatedCurrencyFixture:true,paidUnlock:true,reinforce:true,refundExact:true,equip:true,ownershipAndLevelReload:true,wheelAndTouchFixedDetail:true,decisionHeight:b.height});
  await c.close();
 }
 assert.deepEqual(errors,[]);
 fs.writeFileSync(path.join(out,production?'production-browser.json':'browser-matrix.json'),JSON.stringify({version:'v10.0.5',rows,errors,scope:production?'Production entrypoint; input profile has fixture currency; actual UI spending, save reload and battle loadout':'Current-source visual fixture; actual Flutter TextScaler; fixture currency reset on reload, ownership/level persisted'},null,2));
 console.log(JSON.stringify({passed:rows.length,production,errors}));
 } catch(e) {for(const context of browser.contexts())for(const p of context.pages()){
  await p.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});
  fs.writeFileSync(path.join(out,'failure.txt'),await p.locator('body').ariaSnapshot().catch(()=>''));
 }throw e;
 } finally {await browser.close();}
}
main().catch(e=>{console.error(e);process.exit(1);});
