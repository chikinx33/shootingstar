const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const out=path.join(__dirname,'evidence','visual-v6');fs.mkdirSync(out,{recursive:true});
const key='flutter.shootingstar.profile.v1';
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const errors=[],rows=(process.argv.includes('--release-only')||process.argv.includes('--extras-only'))?JSON.parse(fs.readFileSync(path.join(out,'web-progress.json'),'utf8')).rows:[];
 async function scenario(query,name,work){
  const ctx=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  const page=await ctx.newPage();page.on('pageerror',e=>errors.push(name+': '+e.message));
  await page.route('https://**',r=>r.abort());await page.clock.install();
  await page.goto('http://127.0.0.1:8795/?'+query);await page.waitForTimeout(1800);
  await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  await page.clock.pauseAt(new Date(await page.evaluate(()=>Date.now())+1000));
  await page.getByRole('button',{name:'계속 비행',exact:true}).click();await page.clock.runFor(300);
  if(work)await work(page);else await page.clock.runFor(1400);
  await page.screenshot({path:path.join(out,name+'.png')});
  const text=await page.locator('body').innerText();rows.push({name,text});
  fs.writeFileSync(path.join(out,'web-progress.json'),JSON.stringify({rows,errors},null,2));
  console.log('PASS',name);await ctx.close();
 }
 try{
  if(!process.argv.includes('--release-only') && !process.argv.includes('--extras-only')) {
  for(let world=0;world<10;world++)await scenario('stage='+world*10,'world-'+(world+1));
  for(const weapon of ['pulse','kunai','katana','bat','shotgun','revolver','lightchaser','void','disorder','lance']){
   await scenario('stage=32&mode=weapon&weapon='+weapon,'weapon-'+weapon);
  }
  await scenario('mode=drops','drops-magnet-main',async page=>{
   const text=await page.locator('body').innerText();assert(text.includes('R1 P1 N1'));assert(text.includes('결정 0'));assert(text.includes('자석 회수'));
   assert(text.includes('스킬 선택'));
  });
  await scenario('stage=82&mode=skills','evolved-skills');
  await scenario('stage=20&pilot=yang','pilot-yang',async page=>{
   await page.getByRole('button',{name:'보호 자세',exact:true}).click();await page.clock.runFor(500);
   assert((await page.locator('body').innerText()).includes('고유 20초'));
  });
  }
  if(process.argv.includes('--extras-only')) {
   for(let world=0;world<10;world++)await scenario('stage='+world*10+'&mode=boss','boss-world-'+(world+1));
   await scenario('pilot=metallia','pilot-metallia',async page=>{
    await page.getByRole('button',{name:'원소 전환',exact:true}).click();await page.clock.runFor(300);
    assert((await page.locator('body').innerText()).includes('자세 1'));
   });
   await scenario('pilot=taloxa','pilot-taloxa',async page=>{
    await page.getByRole('button',{name:'체인 동기화',exact:true}).click();await page.clock.runFor(1000);
    assert((await page.locator('body').innerText()).includes('기갑 true'));
   });
   await scenario('pilot=venato','pilot-venato',async page=>{
    await page.getByRole('button',{name:'혈투 개시',exact:true}).click();await page.clock.runFor(1000);
    const hp=Number((await page.locator('body').innerText()).match(/HP (\d+)/)[1]);assert(hp<99000);
   });
   await scenario('mode=stress&stage=82','stress',async page=>{
    await page.clock.runFor(2500);await page.clock.resume();
    const metrics=await page.evaluate(()=>new Promise(resolve=>{
     const samples=[];let prior=performance.now();const start=prior;
     function frame(now){samples.push(now-prior);prior=now;if(now-start<1800)requestAnimationFrame(frame);else{samples.sort((a,b)=>a-b);resolve({frames:samples.length,p50:samples[Math.floor(samples.length*.5)],p95:samples[Math.floor(samples.length*.95)],duration:now-start});}}
     requestAnimationFrame(frame);
    }));
    const text=await page.locator('body').innerText();const enemy=Number(text.match(/적 (\d+)/)[1]),shots=Number(text.match(/탄 (\d+)/)[1]);
    assert(enemy<=260);assert(shots<1000);assert(metrics.frames>10);
    fs.writeFileSync(path.join(out,'stress.json'),JSON.stringify({metrics,enemy,shots,scope:'headless desktop Chrome at mobile viewport; not a physical-phone FPS certificate'},null,2));
   });
  }
  const legacy=JSON.parse(fs.readFileSync(path.join(__dirname,'evidence','campaign-v5','legacy-profile.json'),'utf8'));
  const ctx=await browser.newContext({viewport:{width:360,height:800},isMobile:true,hasTouch:true});
  const page=await ctx.newPage();page.on('pageerror',e=>errors.push('release: '+e.message));
  await page.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated guest"}'}));
  await page.addInitScript(({key,value})=>{if(location.hostname==='127.0.0.1'&&!localStorage.getItem(key))localStorage.setItem(key,JSON.stringify(JSON.stringify(value)));},{key,value:legacy});
  await page.goto('http://127.0.0.1:8791');await page.waitForTimeout(2200);
  await Promise.race([page.locator('flt-semantics-placeholder').waitFor(),page.getByRole('tab',{name:'출격',exact:true}).waitFor()]);
  if(await page.locator('flt-semantics-placeholder').count())await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  if(await page.getByRole('button',{name:'비행 준비 완료',exact:true}).count())await page.getByRole('button',{name:'비행 준비 완료',exact:true}).click();
  await page.getByRole('tab',{name:'격납고',exact:true}).click();await page.waitForTimeout(300);
  const migrated=await page.evaluate(key=>JSON.parse(JSON.parse(localStorage.getItem(key))),key);
  assert.equal(migrated.campaignVersion,1);assert.equal(migrated.clearedStages.length,20);
  assert.equal(migrated.credits,legacy.credits);assert.equal(migrated.blueprints,legacy.blueprints);
  assert.deepEqual(migrated.content.inventory,legacy.content.inventory);
  await page.screenshot({path:path.join(out,'release-loadout.png')});
  fs.writeFileSync(path.join(out,'loadout-aria.txt'),await page.locator('body').ariaSnapshot());
  await page.mouse.move(180,600);await page.mouse.wheel(0,1000);await page.waitForTimeout(300);
  await page.getByRole('button',{name:'주포 계열 펄스 주포',exact:true}).click();await page.waitForTimeout(200);
  fs.writeFileSync(path.join(out,'primary-menu-aria.txt'),await page.locator('body').ariaSnapshot());
  for(let i=0;i<9;i++)await page.keyboard.press('ArrowDown');await page.keyboard.press('Enter');await page.waitForTimeout(300);
  await page.getByRole('button',{name:'조종사 고유 모듈 항로 지휘관',exact:true}).click();await page.waitForTimeout(200);
  for(let i=0;i<10;i++)await page.keyboard.press('ArrowDown');await page.keyboard.press('Enter');await page.waitForTimeout(300);
  const selected=await page.evaluate(key=>JSON.parse(JSON.parse(localStorage.getItem(key))),key);
  assert.equal(selected.selectedArmament,9);assert.equal(selected.selectedPilot,10);
  await page.screenshot({path:path.join(out,'release-selected-loadout.png')});
  await page.reload();await page.waitForTimeout(1300);
  const selectedAgain=await page.evaluate(key=>JSON.parse(JSON.parse(localStorage.getItem(key))),key);assert.equal(selectedAgain.selectedArmament,9);assert.equal(selectedAgain.selectedPilot,10);

  const fixture=JSON.parse(fs.readFileSync(path.join(__dirname,'evidence','campaign-v5','unlocked-profile.json'),'utf8'));
  await page.evaluate(({key,value})=>localStorage.setItem(key,JSON.stringify(JSON.stringify(value))),{key,value:fixture});
  await page.reload();await page.waitForTimeout(1800);
  if(await page.locator('flt-semantics-placeholder').count())await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  await page.getByRole('button',{name:'챕터 선택',exact:true}).first().click();await page.waitForTimeout(300);
  await page.mouse.move(190,600);await page.mouse.wheel(0,1400);await page.waitForTimeout(300);
  await page.screenshot({path:path.join(out,'release-world-picker.png')});
  fs.writeFileSync(path.join(out,'picker-aria.txt'),await page.locator('body').ariaSnapshot());
  await page.getByText('10-10 · 세계 수문장').click();await page.waitForTimeout(300);
  await page.getByRole('button',{name:'선택 완료',exact:true}).click();
  await page.reload();await page.waitForTimeout(1200);
  const persisted=await page.evaluate(key=>JSON.parse(JSON.parse(localStorage.getItem(key))),key);
  assert.equal(persisted.selectedStage,99);assert.equal(persisted.credits,fixture.credits);
  const version=await page.evaluate(()=>fetch('/version.json').then(r=>r.json()));assert.equal(version.version,'6.0.0');
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'web-result.json'),JSON.stringify({rows,legacyPreserved:true,reloadPreserved:true,version,errors,fixture:'QA battles have high hull and injected loadouts; standard app uses isolated local guest saves; no production APIs called'},null,2));
  console.log('PASS release legacy migration, loadout layout, 10-world picker, reload; errors=0');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
