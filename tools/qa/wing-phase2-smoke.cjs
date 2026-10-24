// Real release entrypoint and controls in a fresh profile. No game-state injection.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','wing-phase2');
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
  await p.goto(process.env.QA_URL||'http://127.0.0.1:8797/?ui=v10.0.3');
  for(let i=0;i<75;i++) {
   const placeholder=p.locator('flt-semantics-placeholder');
   if(await placeholder.count())await placeholder.evaluate(e=>e.click());
   if(await p.getByRole('button',{name:'성장',exact:true}).count())break;
   await p.waitForTimeout(200);
  }
  await p.waitForLoadState('networkidle');
  assert(await p.getByText('v10.0.3',{exact:true}).count());
  await p.getByRole('button',{name:/ · 출격$/}).first().click();
  const done=p.getByRole('button',{name:'비행 준비 완료',exact:true});
  await reveal(p,done);await done.click();
  await p.getByRole('button',{name:'일시정지',exact:true}).waitFor();
  fs.mkdirSync(out,{recursive:true});
  await p.clock.install();
  let branch=false,acquired='';
  const weaponNames=['레이저 발사기','추적 로켓','이온 낙뢰','궤도 수호자','관통 드릴','요격 드론','중력 지뢰','반사 플라스마구','중량 탄두','귀환 광륜','에너지 역장','광자 수레바퀴','플라스마 장판','가시 위성','폭격 드론 B'];
  for(let i=0;i<220;i++) {
   await p.keyboard.down(i%24<18?'ArrowUp':'ArrowDown');
   await p.clock.runFor(250);
   await p.keyboard.up('ArrowUp');await p.keyboard.up('ArrowDown');
   const focus=p.getByRole('button',{name:/^집속 펄스/});
   if(!branch && await focus.count()) {
    fs.writeFileSync(path.join(out,'branch-accessibility.txt'),await focus.ariaSnapshot());
    await p.screenshot({path:path.join(out,'recipe-choice-390.png')});
    const box=await focus.boundingBox();await p.touchscreen.tap(box.x+box.width/2,box.y+box.height/2);
    await p.clock.runFor(250);branch=true;
   } else if(branch) {
    for(const name of weaponNames) {
     const card=p.getByRole('button',{name:new RegExp('^'+name)});
     if(!await card.count())continue;
     await p.clock.resume();await p.waitForTimeout(250);
     await p.screenshot({path:path.join(out,'role-choice-390.png')});
     await reveal(p,card,88);await card.click();
     acquired=name;break;
    }
   }
   if(acquired)break;
  }
  assert(branch&&acquired,'Reach real upgrades and acquire one auxiliary');
  await p.getByRole('button',{name:'일시정지',exact:true}).click();
  const actualStats=p.getByRole('button',{name:'전투 통계',exact:true});
  await reveal(p,actualStats);await actualStats.click();
  await p.getByRole('tab',{name:'현재 빌드',exact:true}).click();await p.waitForTimeout(400);
  assert(await p.getByText(/정면 돌파 · (필요|활성)/).count());
  await p.screenshot({path:path.join(out,'synergy-build-390.png')});
  fs.writeFileSync(path.join(out,'build-semantics.json'),JSON.stringify(await p.locator('flt-semantics').allTextContents(),null,2));
  assert.deepEqual(errors,[]);
  const report={version:'v10.0.3',isolatedProfile:true,productionEntrypoint:true,virtualClock:true,
    branchRecipeHint:true,realAuxiliaryAcquired:acquired,synergyRequirementsVisible:true,
    synergyProcExecution:'Covered by engine tests, not asserted by this UI run',errors};
  fs.writeFileSync(path.join(out,'smoke.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
