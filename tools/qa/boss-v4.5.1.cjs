const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const out=path.join(__dirname,'evidence','boss-v4.5.1');fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const errors=[],rows=[];
 try {
  for(const [stage,strong] of [[0,false],[1,false],[2,false],[0,true]]) {
   const context=await browser.newContext({viewport:{width:360,height:800},isMobile:true,hasTouch:true});
   const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));
   await page.route('https://**',r=>r.abort());
   await page.clock.install();
   await page.goto(`http://127.0.0.1:8792/?stage=${stage}&strong=${strong?1:0}`);
   await page.waitForTimeout(3000);
   await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
   await page.clock.pauseAt(new Date(await page.evaluate(()=>Date.now())+1000));
   await page.getByRole('button',{name:'계속 비행',exact:true}).click();
   await page.clock.runFor(600);
   const prefix=`stage${stage}-${strong?'strong':'basic'}`;
   const warning=await page.locator('body').innerText();assert(warning.includes('예고')||warning.includes('조준 고정'));
   await page.screenshot({path:path.join(out,prefix+'-warning.png')});
   await page.getByRole('button',{name:'일시정지',exact:true}).click();await page.clock.runFor(100);
   const frozen=(await page.locator('body').innerText()).match(/주기 [\d.]+/)[0];
   await page.clock.runFor(1000);assert.equal((await page.locator('body').innerText()).match(/주기 [\d.]+/)[0],frozen);
   await page.getByRole('button',{name:'계속 비행',exact:true}).click();
   await page.keyboard.down('d');await page.clock.runFor(400);await page.keyboard.up('d');
   await page.clock.runFor(600);
   await page.screenshot({path:path.join(out,prefix+'-attack.png')});
   if(!strong){
    await page.clock.runFor(1000);
    assert((await page.locator('body').innerText()).includes('코어 개방'));
    await page.screenshot({path:path.join(out,prefix+'-core.png')});
   }else{
    await page.clock.runFor(14000);
    const text=await page.locator('body').innerText();assert(text.includes('격파 1'));assert(text.includes('단계 0,1,2'));
    assert(/공격 [3-9]/.test(text));
    await page.screenshot({path:path.join(out,prefix+'-defeated.png')});
   }
   rows.push({stage,strong,warning,pauseFreezes:true,finalText:await page.locator('body').innerText()});
   await context.close();
  }
  fs.writeFileSync(path.join(out,'web-patterns.json'),JSON.stringify({rows,errors},null,2));
  const page=await browser.newPage({viewport:{width:390,height:844}});
  page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"QA guest"}'}));
  await page.goto('http://127.0.0.1:8791');await page.waitForTimeout(2500);
  await page.screenshot({path:path.join(out,'release-before-semantics.png')});
  await Promise.race([page.locator('flt-semantics-placeholder').waitFor(),page.getByRole('tab',{name:'출격',exact:true}).waitFor()]);
  if(await page.locator('flt-semantics-placeholder').count()) await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  console.log('RELEASE ERRORS',JSON.stringify(errors));
  const version=await page.evaluate(()=>fetch('/version.json').then(r=>r.json()));assert.equal(version.version,'4.5.1');
  assert(!(await page.locator('body').innerText()).includes('QA ·'));
  await page.screenshot({path:path.join(out,'release-home.png')});
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'web-result.json'),JSON.stringify({fixture:'Separate QA entrypoint with real BattleScreen, GameEngine and BattlePainter; high hull only to inspect patterns, not survival proof',rows,version,errors},null,2));
  console.log('PASS 3 patterns, warning/attack/core, paused clocks, strong build 3 phases and kill; production build smoke');
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});

