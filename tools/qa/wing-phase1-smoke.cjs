// Production entrypoint, isolated browser profile, real controls. No QA game state.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','wing-phase1');
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
  await p.goto(process.env.QA_URL||'http://127.0.0.1:8797/?ui=v10.0.2');
  for(let i=0;i<75;i++) {
   const placeholder=p.locator('flt-semantics-placeholder');
   if(await placeholder.count())await placeholder.evaluate(e=>e.click());
   if(await p.getByRole('button',{name:'성장',exact:true}).count())break;
   await p.waitForTimeout(200);
  }
  await p.waitForLoadState('networkidle');
  assert(await p.getByText('v10.0.2',{exact:true}).count());
  await p.getByRole('button',{name:/ · 출격$/}).first().click();
  const done=p.getByRole('button',{name:'비행 준비 완료',exact:true});
  await reveal(p,done); await done.click();
  await p.getByRole('button',{name:'일시정지',exact:true}).waitFor();
  fs.mkdirSync(out,{recursive:true});
  await p.clock.install();
  let selected=false;
  for(let i=0;i<180;i++) {
   // Fly toward the defeated front enemies to recover their experience.
   await p.keyboard.down(i%24<18?'ArrowUp':'ArrowDown');
   await p.clock.runFor(250);
   await p.keyboard.up('ArrowUp');await p.keyboard.up('ArrowDown');
   const focus=p.getByRole('button',{name:/^집속 펄스/});
   if(!selected && await focus.count()) {
    await p.screenshot({path:path.join(out,'branches-390.png')});
    const box=await focus.boundingBox();
    await p.touchscreen.tap(box.x+box.width/2,box.y+box.height/2);
    await p.clock.runFor(300);
    await p.clock.resume();
    await p.waitForTimeout(600);
    fs.writeFileSync(path.join(out,'after-choice-semantics.json'),JSON.stringify(await p.locator('flt-semantics').allTextContents(),null,2));
    await p.screenshot({path:path.join(out,'after-choice-390.png')});
    assert(!(await focus.count()),'Choosing a branch must dismiss the real decision screen');
    selected=true;
    await p.screenshot({path:path.join(out,'focus-hud-390.png')});
   }
   if(selected)break;
  }
  const texts=await p.locator('flt-semantics').allTextContents();
  fs.writeFileSync(path.join(out,'last-semantics.json'),JSON.stringify(texts,null,2));
  await p.screenshot({path:path.join(out,'last-frame-390.png')});
  assert(selected,'Real battle must reach level 2 and select a branch');
  assert.deepEqual(errors,[]);
  const report={version:'v10.0.2',productionEntrypoint:true,isolatedProfile:true,
    virtualClock:true,realLevelUpAndBranchSelection:selected,
    formationConfirmation:'Review after-choice-390.png; behavior is covered by engine tests',errors};
  fs.writeFileSync(path.join(out,'smoke.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report));
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
