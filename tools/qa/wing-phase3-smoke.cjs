// Real production controls and a fresh profile. Virtual time shortens charging only.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','wing-phase3');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const errors=[];
 try {
  const c=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  await c.route('https://**',r=>r.abort());
  await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated smoke"}'}));
  const p=await c.newPage();p.setDefaultTimeout(12000);
  p.on('pageerror',e=>errors.push(e.message));
  p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
  await p.goto(process.env.QA_URL||'http://127.0.0.1:8797/?ui=v10.0.4');
  for(let i=0;i<75;i++) {
   const placeholder=p.locator('flt-semantics-placeholder');
   if(await placeholder.count())await placeholder.evaluate(e=>e.click());
   if(await p.getByRole('button',{name:'성장',exact:true}).count())break;
   await p.waitForTimeout(200);
  }
  await p.waitForLoadState('networkidle');
  assert(await p.getByText('v10.0.4',{exact:true}).count());
  await p.getByRole('button',{name:/ · 출격$/}).first().click();
  const done=p.getByRole('button',{name:'비행 준비 완료',exact:true});
  await reveal(p,done);await done.click();
  await p.getByRole('button',{name:'일시정지',exact:true}).waitFor();
  fs.mkdirSync(out,{recursive:true});
  await p.screenshot({path:path.join(out,'charging-390.png')});
  await p.clock.install();
  let cast=false;
  for(let i=0;i<230;i++) {
   const key=i%20<10?'ArrowLeft':'ArrowRight';
   await p.keyboard.down(key);await p.clock.runFor(200);await p.keyboard.up(key);
   const choice=p.getByRole('button',{name:/^집속 펄스/});
   if(await choice.count()) {
    const b=await choice.boundingBox();await p.touchscreen.tap(b.x+b.width/2,b.y+b.height/2);
    await p.clock.runFor(100);
   }
   const fire=p.getByRole('button',{name:'궁극기 항성포 발사',exact:true});
   if(await fire.count() && await fire.isEnabled()) {
    await p.clock.resume();await p.waitForTimeout(150);
    await p.screenshot({path:path.join(out,'ready-390.png')});
    const box=await fire.boundingBox();
    assert(box&&box.height>=72&&box.x>=0&&box.x+box.width<=390);
    await p.touchscreen.tap(box.x+box.width/2,box.y+box.height/2);
    await p.waitForTimeout(250);
    await p.getByRole('button',{name:'궁극기 항성포 발사 중',exact:true}).waitFor();
    await p.screenshot({path:path.join(out,'ultimate-active-390.png')});
    cast=true;break;
   }
  }
  assert(cast,'Real charged ultimate must be usable');
  await p.getByRole('button',{name:'일시정지',exact:true}).click();
  const stats=p.getByRole('button',{name:'전투 통계',exact:true});
  await reveal(p,stats);await stats.click();
  await p.getByRole('tab',{name:'현재 빌드',exact:true}).click();await p.waitForTimeout(400);
  assert(await p.getByText(/항성포 · 충전 .* · 사용 1회/).count());
  await p.screenshot({path:path.join(out,'ultimate-statistics-390.png')});
  assert.deepEqual(errors,[]);
  const report={version:'v10.0.4',productionEntrypoint:true,isolatedProfile:true,virtualClock:true,
    realChargeAndButtonCast:true,castRecordedInStatistics:true,errors,
    shieldCounter:'Engine actual-interception and all-armament tests; combined UI widget tests'};
  fs.writeFileSync(path.join(out,'smoke.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report));
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
