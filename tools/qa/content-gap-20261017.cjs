// Isolated local browser evidence. No production account or reference-game runtime.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const out=path.join(__dirname,'evidence','content-gap-20261017');
const key='flutter.shootingstar.profile.v1';
fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const errors=[],rows=[];
 async function semantics(p){if(await p.locator('flt-semantics-placeholder').count())await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());await p.waitForTimeout(200);}
 async function open(width,height,url='http://127.0.0.1:8797'){
  const c=await browser.newContext({viewport:{width,height},isMobile:width<500,hasTouch:true});const p=await c.newPage();
  p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
  await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated QA guest"}'}));await c.route('https://**',r=>r.abort());
  await p.goto(url);await p.waitForTimeout(1100);await semantics(p);return {c,p};
 }
 const btn=(p,name)=>p.getByRole('button',{name,exact:true});
 async function click(p,name){await btn(p,name).first().click();await p.waitForTimeout(220);}
 async function chip(p,name){await p.getByRole('checkbox',{name,exact:true}).click();await p.waitForTimeout(200);}
 async function shot(p,name){await p.screenshot({path:path.join(out,name+'.png')});}
 async function saved(p){return p.evaluate(key=>{let v=localStorage.getItem(key);for(let i=0;i<3&&typeof v==='string';i++)v=JSON.parse(v);return v;},key);}
 async function reload(p){await p.reload();await p.waitForTimeout(900);await semantics(p);}
 async function reveal(p,locator){for(let i=0;i<30;i++){const b=await locator.boundingBox({timeout:250}).catch(()=>null);const h=p.viewportSize().height;if(b&&b.y>=70&&b.y+b.height<h-4)return;await p.mouse.move(p.viewportSize().width/2,h*.72);await p.mouse.wheel(0,b&&b.y<70?-130:150);await p.waitForTimeout(140);}throw Error('Unable to reveal '+locator);}
 try{
  for(const [w,h] of (process.argv.includes('--additional-only')||process.argv.includes('--presets-only')?[]:[[320,568],[360,640],[390,844],[430,932]])){
   console.log('mobile',w);const {c,p}=await open(w,h);
   await shot(p,`home-${w}`);
   await click(p,'임무·출석');await chip(p,'출석');await shot(p,`signin-${w}`);
   await click(p,'오늘 출석 보상 받기');let s=await saved(p);
   assert.equal(s.content.journal.signIns,1);assert.equal(s.content.collections.keys,1);
   assert(await btn(p,'오늘 수령 완료').isDisabled());
   const link=btn(p,'수집품 조사와 성장');await reveal(p,link);await link.click();await p.waitForTimeout(180);
   await click(p,'유물 조사 · 탐사권 1');s=await saved(p);assert.equal(s.content.collections.keys,0);assert.equal(s.content.collections.shards[0],3);
   const restore=btn(p,'복원 · 조각 1').first();await reveal(p,restore);await restore.click();await p.waitForTimeout(180);
   const upgrade=btn(p,'강화 · 조각 2').first();await upgrade.click();await p.waitForTimeout(180);
   s=await saved(p);assert.equal(s.content.collections.levels[0],2);assert.equal(s.content.collections.shards[0],0);
   await shot(p,`collections-${w}`);await reload(p);let r=await saved(p);assert.deepEqual(r.content.collections,s.content.collections);assert.equal(r.content.journal.signIns,1);
   await click(p,'진화');await shot(p,`talents-before-${w}`);await btn(p,'80 C').first().click();await p.waitForTimeout(220);
   r=await saved(p);assert.equal(r.attackLevel,1);assert.equal(r.credits,100);await shot(p,`talents-after-${w}`);
   await reload(p);r=await saved(p);assert.equal(r.attackLevel,1);assert.equal(r.credits,100);
   await click(p,'임무·출석');await shot(p,`missions-${w}`);await chip(p,'항로 보상');await shot(p,`chapter-${w}`);
   assert(await btn(p,'항로 보상 받기 1').isDisabled());await chip(p,'순찰');
   const quick=btn(p,'빠른 순찰 보상 받기');await reveal(p,quick);assert(await quick.isDisabled());await shot(p,`patrol-${w}`);
   rows.push({name:`mobile-${w}x${h}`,signInOnce:true,collectionDrawRestoreUpgrade:true,talentSharedUpgrade:true,reloadPreserved:true,lockedChapterAndQuickPatrol:true});await c.close();
  }
  if(!process.argv.includes('--additional-only')){
   console.log('presets');const {c,p}=await open(390,844);await click(p,'격납고');await click(p,'편성 저장·불러오기');await shot(p,'presets-empty');
   await btn(p,'현재 구성 저장').first().click();await p.getByRole('textbox').fill('보스 공략');await click(p,'저장');let s=await saved(p);assert.equal(s.hangarPresets[0].name,'보스 공략');
   await click(p,'구성 확인 · 적용');await shot(p,'preset-preview');await click(p,'이 구성 적용');let after=await saved(p);assert.equal(after.credits,s.credits);assert.deepEqual(after.content.equippedGear,s.content.equippedGear);
   await click(p,'이름 변경');await p.getByRole('textbox').fill('항로 탐사');await click(p,'저장');await shot(p,'presets-saved');await reload(p);
   s=await saved(p);assert.equal(s.hangarPresets[0].name,'항로 탐사');await click(p,'격납고');await click(p,'편성 저장·불러오기');await click(p,'삭제');await btn(p,'삭제').last().click();await p.waitForTimeout(150);assert.equal((await saved(p)).hangarPresets[0],null);
   rows.push({name:'six-preset-save-preview-apply-rename-reload-delete',currencyPreserved:true});await c.close();
  }
  if(!process.argv.includes('--additional-only')&&!process.argv.includes('--presets-only')){
   console.log('desktop');const {c,p}=await open(1280,900);await click(p,'임무·출석');await shot(p,'desktop-activity');rows.push({name:'desktop-1280x900'});await c.close();
  }
  if(!process.argv.includes('--presets-only')){
   console.log('eligible rewards UI fixture');const {c,p}=await open(390,844);await click(p,'임무·출석');await chip(p,'출석');await click(p,'오늘 출석 보상 받기');const s=await saved(p);
   // Inject only progression prerequisites into this isolated browser. This is
   // a UI fixture; eligible combat settlement is tested in fleet_journal_test.
   s.content.dailyRuns=1;s.content.dailyKills=100;s.content.dailyUpgrades=1;
   Object.assign(s.content.journal,{weeklyRuns:5,weeklyKills:1200,weeklyBosses:3,weeklySeconds:1800,chapterWins:[0]});
   await p.evaluate(({key,s})=>localStorage.setItem(key,JSON.stringify(JSON.stringify(s))),{key,s});await reload(p);await click(p,'임무·출석');
   for(let i=1;i<=3;i++){const b=btn(p,`일일 임무 ${i} 보상 받기`);await reveal(p,b);await b.click();await p.waitForTimeout(160);}
   for(let i=1;i<=3;i++){const b=btn(p,`일일 활동 상자 ${i}`);await reveal(p,b);await b.click();await p.waitForTimeout(160);}await shot(p,'daily-chests-claimed');
   for(let i=1;i<=4;i++){const b=btn(p,`주간 임무 ${i} 보상 받기`);await reveal(p,b);await b.click();await p.waitForTimeout(160);}
   for(let i=1;i<=2;i++){const b=btn(p,`주간 활동 상자 ${i}`);await reveal(p,b);await b.click();await p.waitForTimeout(160);}await shot(p,'weekly-chests-claimed');
   await chip(p,'항로 보상');for(let i=1;i<=3;i++){const b=btn(p,`항로 보상 받기 ${i}`);await reveal(p,b);await b.click();await p.waitForTimeout(160);}await shot(p,'chapter-chests-claimed');
   await chip(p,'순찰');const quick=btn(p,'빠른 순찰 보상 받기');await reveal(p,quick);await quick.click();await p.waitForTimeout(180);await shot(p,'quick-patrol-claimed');
   const r=await saved(p);assert.equal(r.content.collections.keys,11);assert.deepEqual(r.content.journal.dailyChests,[0,1,2]);assert.deepEqual(r.content.journal.weeklyClaims,[0,1,2,3]);assert.deepEqual(r.content.journal.weeklyChests,[0,1]);assert.deepEqual(r.content.journal.chapterClaims,[0,1,2]);assert.equal(r.content.journal.quickPatrolClaimed,true);assert.equal(r.content.lastPatrol,s.content.lastPatrol);
   await reload(p);const restored=await saved(p);assert.deepEqual(restored.content.journal,r.content.journal);assert.equal(restored.content.collections.keys,11);rows.push({name:'eligible-activity-reward-UI-fixture',dailyWeeklyChapterAndQuickClaims:true,collectionKeys:11,reloadPreserved:true,scope:'Prerequisites injected in isolated local save; no claim of combat duration or original-game parity'});await c.close();
  }
  if(!process.argv.includes('--menus-only')&&!process.argv.includes('--presets-only')){
   for(const [w,h] of [[320,568],[390,844]]){
    console.log('statistics',w);const {c,p}=await open(w,h,'http://127.0.0.1:8798/?scene=stress');await p.waitForTimeout(900);await click(p,'일시정지');await click(p,'전투 통계');await shot(p,`statistics-damage-${w}`);
    await p.getByRole('tab',{name:'현재 빌드',exact:true}).click();await p.waitForTimeout(400);await shot(p,`statistics-build-${w}`);
    await click(p,'통계 닫기');assert(await btn(p,'계속 비행').isVisible());await click(p,'귀환 · 현재 보상 정산');await click(p,'전투 통계');await shot(p,`statistics-result-${w}`);await click(p,'통계 닫기');
    assert(await btn(p,'다시 출격').isVisible());rows.push({name:`battle-statistics-pause-result-${w}`,fixture:'450-enemy high-hull fixture; actual engine damage meter'});await c.close();
   }
  }
  assert.deepEqual(errors,[]);if(process.argv.includes('--additional-only')||process.argv.includes('--presets-only')){const old=JSON.parse(fs.readFileSync(path.join(out,'browser-result.json')));for(const row of old.rows)if(!rows.some(r=>r.name===row.name))rows.unshift(row);errors.push(...old.errors);}fs.writeFileSync(path.join(out,'browser-result.json'),JSON.stringify({rows,errors,scope:'Isolated local browser guests, no production writes. Reference XAPK statically inspected, never run.'},null,2));console.log(JSON.stringify({passed:rows.length,rows,errors},null,2));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});


