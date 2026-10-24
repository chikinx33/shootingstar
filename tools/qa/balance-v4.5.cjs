const {chromium}=require('playwright');
const fs=require('fs'), path=require('path'), assert=require('assert');
const out=path.join(__dirname,'evidence','balance-v4.5');fs.mkdirSync(out,{recursive:true});
const key='flutter.shootingstar.profile.v1';
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 try {
  const page=await browser.newPage({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated guest QA"}'}));
  await page.route('https://**',r=>r.abort());
  await page.clock.install();
  await page.goto('http://127.0.0.1:8791');await page.waitForTimeout(3500);
  await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  await page.screenshot({path:path.join(out,'01-home.png')});
  let choices=0,rerolled=false,result='tech-only fixture';
  if(!process.argv.includes('--tech-only')){
  await page.getByRole('button',{name:'잔광 외곽 · 출격',exact:true}).click();
  await page.getByRole('button',{name:'비행 준비 완료',exact:true}).click();
  await page.clock.pauseAt(new Date(await page.evaluate(()=>Date.now())+1000));

  for(let i=0;i<23;i++){
   const text=await page.locator('body').innerText();
   if(text.includes('다음엔 꼭 이긴다냥')||text.includes('집을 지켜 냈다냥!'))break;
   if(text.includes('스킬 선택')){
    if(!rerolled){
     await page.screenshot({path:path.join(out,'02-choice-before.png')});
     await page.getByRole('button',{name:'다시 뽑기 · 3회',exact:true}).click();
     await page.clock.runFor(100);
     assert(await page.getByRole('button',{name:'다시 뽑기 · 2회',exact:true}).count());
     await page.screenshot({path:path.join(out,'03-choice-rerolled.png')});rerolled=true;
    }
    const buttons=page.getByRole('button').filter({hasNotText:/일시정지|다시 뽑기|교체/});
    await buttons.first().click();choices++;await page.clock.runFor(100);
   }
   const direction=['d','s','a','w'][Math.floor(i/3)%4];
   await page.keyboard.down(direction);await page.clock.runFor(1400);await page.keyboard.up(direction);
  }
  if(await page.getByRole('button',{name:'일시정지',exact:true}).count()){
   await page.getByRole('button',{name:'일시정지',exact:true}).click();await page.clock.runFor(100);
   await page.getByRole('button',{name:'귀환 · 현재 보상 정산',exact:true}).click();await page.clock.runFor(100);
  }
  await page.screenshot({path:path.join(out,'04-result.png')});
  result=await page.locator('body').innerText();assert(choices>0&&rerolled);
  await page.getByRole('button',{name:'성장 정비 · 귀환',exact:true}).click();await page.clock.runFor(500);
  await page.clock.resume();
  }
  const save=await page.evaluate(key=>JSON.parse(JSON.parse(localStorage.getItem(key))) || {version:4,content:{}},key);
  // An isolated legacy-account fixture; no user or server storage is accessed.
  save.credits=9999;save.blueprints=55;save.clearedStages=[0];
  delete save.content.starterTechUnlocked;delete save.content.starterTechClaimed;delete save.content.salvageSeconds;
  await page.evaluate(({key,save})=>localStorage.setItem(key,JSON.stringify(JSON.stringify(save))),{key,save});
  await page.reload();await page.waitForTimeout(2000);
  await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  await page.getByRole('tab',{name:'성장',exact:true}).click();
  await page.waitForTimeout(400);
  await page.screenshot({path:path.join(out,'debug-growth.png')});
  await page.getByRole('checkbox',{name:'테크',exact:true}).click();
  await page.waitForTimeout(350);
  await page.screenshot({path:path.join(out,'05-legacy-tech-choice.png')});
  
  const choice=page.getByRole('button',{name:'관통 증폭기 · 주포 1회 관통',exact:true});await choice.click();
  await page.getByRole('button',{name:'선택 확정',exact:true}).click();await page.waitForTimeout(500);
  const claimed=await page.evaluate(key=>JSON.parse(JSON.parse(localStorage.getItem(key))),key);
  assert.equal(claimed.content.starterTechClaimed,true);assert.equal(claimed.credits,9999);assert.equal(claimed.blueprints,55);
  if(save.content.inventory) assert.deepEqual(claimed.content.inventory,save.content.inventory);
  await page.setViewportSize({width:360,height:800});await page.screenshot({path:path.join(out,'06-tech-mobile360.png')});
  await page.reload();await page.waitForTimeout(1800);
  const reloaded=await page.evaluate(key=>JSON.parse(JSON.parse(localStorage.getItem(key))),key);assert.deepEqual(reloaded,claimed);
  await page.setViewportSize({width:1280,height:900});await page.screenshot({path:path.join(out,'07-desktop.png')});
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,process.argv.includes('--tech-only')?'web-tech-result.json':'web-result.json'),JSON.stringify({choices,rerolled,result,legacyPreserved:true,rareClaimPersists:true,errors},null,2));
  console.log('PASS',choices,'choices, reroll, legacy preservation, rare tech claim and reload');
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});



