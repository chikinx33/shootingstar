// Local-only browser guests. Prerequisite save fixtures do not prove long-term
// earning or survival. The production app contains no fixture routes.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const out=path.join(__dirname,'evidence','advanced-gap-20261017');fs.mkdirSync(out,{recursive:true});
const key='flutter.shootingstar.profile.v1';
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const rows=[],errors=[];let last;
 const btn=(p,name)=>p.getByRole('button',{name,exact:true});
 async function semantics(p){if(await p.locator('flt-semantics-placeholder').count())await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());await p.waitForTimeout(180);}
 async function open(w,h,url='http://127.0.0.1:8797'){
  const c=await browser.newContext({viewport:{width:w,height:h},isMobile:w<500,hasTouch:true});const p=await c.newPage();last=p;
  p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
  await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated QA"}'}));await c.route('https://**',r=>r.abort());
  await p.goto(url);await p.waitForTimeout(1100);await semantics(p);return {c,p};
 }
 async function reveal(p,l){for(let i=0;i<50;i++){const b=await l.boundingBox({timeout:150}).catch(()=>null),h=p.viewportSize().height;if(b&&b.y>=56&&b.y+b.height<=h+1)return;await p.mouse.move(p.viewportSize().width*.55,h*.73);await p.mouse.wheel(0,b&&b.y<56?-120:145);await p.waitForTimeout(85);}throw Error('Unable to reveal '+l);}
 async function top(p){await p.mouse.move(p.viewportSize().width*.55,p.viewportSize().height*.7);await p.mouse.wheel(0,-12000);await p.waitForTimeout(220);}
 async function click(p,name){const l=btn(p,name).first();if(name!=='일시정지')await reveal(p,l);await l.click();await p.waitForTimeout(220);}
 async function chip(p,name){const l=p.getByRole('checkbox',{name,exact:true});await reveal(p,l);await l.click();await p.waitForTimeout(180);}
 async function shot(p,name){await p.screenshot({path:path.join(out,name+'.png')});}
 async function saved(p){return p.evaluate(key=>{let v=localStorage.getItem(key);for(let i=0;i<3&&typeof v==='string';i++)v=JSON.parse(v);return v;},key);}
 async function reload(p){await p.reload();await p.waitForTimeout(900);await semantics(p);}
 async function inject(p,s){await p.evaluate(({key,s})=>localStorage.setItem(key,JSON.stringify(JSON.stringify(s))),{key,s});await reload(p);}
 async function seedLegacy(p){
  await click(p,'임무·출석');await chip(p,'출석');await click(p,'오늘 출석 보상 받기');const s=await saved(p);
  s.onboarded=true;s.soundEnabled=false;s.credits=6000;s.blueprints=100;
  Object.assign(s.content,{petFood:500,petLevels:[5,0,0],petRanks:[1,0,0],petShards:[10,0,0]});
  s.content.inventory[0].rank=2;
  for(const [id,spec,locked] of [[7,0,false],[8,1,false],[9,0,true]])s.content.inventory.push({id,spec,rank:1,level:0,locked,spentCredits:0,spentPlans:0});
  s.hangarPresets[0]={name:'보존할 편성',ship:0,pilot:0,armament:0,equipment:0,gearIds:[1,2,3,4,5,6],techIds:[],pet:0,assistPets:[]};
  for(const k of ['advancedProgressionVersion','dailyChallenge','advancedEquipment','petBond'])delete s.content[k];
  await inject(p,s);const r=await saved(p);assert.deepEqual(r.content.inventory,s.content.inventory);assert.equal(r.hangarPresets[0].name,'보존할 편성');assert.equal(r.content.advancedProgressionVersion,1);
  return r;
 }
 async function dailyMenu(p){await click(p,'도전');await click(p,'일일 순환 도전 · 교환소');}
 async function gearMenu(p){await click(p,'성장');await click(p,'고급 장비 성장 · 정련·융합');}
 async function petMenu(p){await click(p,'성장');await chip(p,'펫');await click(p,'각성·호감도 · 50 / 300');}
 try{
  if(!process.argv.includes('--fixtures-only'))for(const [w,h] of [[320,568],[360,640],[390,844],[430,932]]){
   console.log('mobile',w);const {c,p}=await open(w,h);await seedLegacy(p);
   await dailyMenu(p);await shot(p,`daily-${w}`);await click(p,'정찰 도전 시작');await p.waitForTimeout(500);await shot(p,`daily-combat-${w}`);
   await click(p,'일시정지');await click(p,'도전 중단 · 토큰 보상 없음');await shot(p,`daily-abandoned-${w}`);let s=await saved(p);
   assert.equal(s.content.dailyChallenge.tokens,0);assert.deepEqual(s.clearedStages,[]);assert.equal(s.selectedStage,0);
   await click(p,'도전 목록으로');await chip(p,'토큰 교환소');await shot(p,`daily-exchange-locked-${w}`);
   assert(await btn(p,'토큰 3 · 교환').isDisabled());
   // Isolated UI prerequisite fixture for earned currency and favor.
   s=await saved(p);s.content.dailyChallenge.tokens=16;s.content.petBond.favor[0]=50;await inject(p,s);
   await dailyMenu(p);await chip(p,'토큰 교환소');await click(p,'토큰 3 · 교환');await click(p,'토큰 3 · 교환');assert(await btn(p,'토큰 3 · 교환').isDisabled());
   await click(p,'토큰 8 · 교환');await shot(p,`daily-exchange-used-${w}`);s=await saved(p);assert.equal(s.content.dailyChallenge.tokens,2);assert.equal(s.blueprints,104);assert.equal(s.content.collections.keys,2);
   await reload(p);await gearMenu(p);await shot(p,`advanced-before-${w}`);
   for(const cost of [150,250,350])await click(p,`정밀 조정 · ${cost} C + 설계도 ${cost===150?3:cost===250?5:7}`);
   await chip(p,'방호');await shot(p,`advanced-refined-${w}`);
   for(const name of ['펄스 블래스터 #7 · 우수 Lv.0','유성 추적기 #8 · 우수 Lv.0'])await chip(p,name);
   await click(p,'융합 확인 · 600 C + 설계도 10');await shot(p,`fusion-confirm-${w}`);await click(p,'취소');
   assert.equal((await saved(p)).content.inventory.length,9);
   await click(p,'융합 확인 · 600 C + 설계도 10');await click(p,'선택한 2개로 융합');s=await saved(p);assert.equal(s.credits,4650);assert.equal(s.blueprints,79);assert.equal(s.content.advancedEquipment.entries[0].ascension,1);assert.equal(s.content.inventory.length,7);assert(s.content.inventory.some(g=>g.id===9&&g.locked));
   await shot(p,`advanced-fused-${w}`);await reload(p);await gearMenu(p);await click(p,'정밀 성장 초기화 · 자원·융합 재료 반환');await click(p,'정밀 성장만 초기화');s=await saved(p);assert.equal(s.credits,6000);assert.equal(s.blueprints,104);assert.equal(s.content.inventory.length,9);assert.deepEqual(s.content.equippedGear,[1,2,3,4,5,6]);assert.equal(s.hangarPresets[0].name,'보존할 편성');
   await reload(p);await petMenu(p);await shot(p,`pet-favor-${w}`);await click(p,'먹이 10 선물 · 호감도 +10');await click(p,'펫 각성 1단계 · 100 C');await shot(p,`pet-awakened-${w}`);
   const swift=p.getByRole('button',{name:/^신속 동행/});await reveal(p,swift);await swift.click();await p.waitForTimeout(180);s=await saved(p);assert.equal(s.content.petBond.skills[0],1);assert.equal(s.content.petBond.awakening[0],1);assert.equal(s.content.petBond.favor[0],60);assert.equal(s.content.petFood,470);assert.equal(s.content.petShards[0],9);
   await shot(p,`pet-skill-${w}`);await reload(p);await click(p,'성장');await chip(p,'펫');await click(p,'각성·호감도 · 60 / 300');await click(p,'각성 재료 반환·초기화');await shot(p,`pet-reset-confirm-${w}`);await click(p,'취소');assert.equal((await saved(p)).content.petBond.awakening[0],1);
   await click(p,'각성 재료 반환·초기화');await click(p,'각성 초기화');s=await saved(p);assert.equal(s.content.petBond.awakening[0],0);assert.equal(s.content.petBond.favor[0],60);assert.equal(s.credits,6000);assert.equal(s.content.petFood,490);assert.equal(s.content.petShards[0],10);assert.deepEqual(s.content.petLevels,[5,0,0]);assert.deepEqual(s.content.petRanks,[1,0,0]);
   rows.push({name:`mobile-${w}x${h}`,legacyMigration:true,realDailyLaunchAbandonNoReward:true,exchangeLimits:true,refineFusionReloadExactRefund:true,gearAndPresetIdsPreserved:true,petGiftAwakenSkillReloadCancelReset:true,scope:'Rank/material/favor/token prerequisites seeded only in isolated browser storage'});await c.close();
  }
  for(const [w,h] of [[320,568],[390,844]]){
   console.log('daily victory fixture',w);const {c,p}=await open(w,h,'http://127.0.0.1:8798/?scene=daily-victory&tier=2');await p.waitForTimeout(400);await shot(p,`daily-victory-${w}`);
   let s=await saved(p);assert.equal(s.content.dailyChallenge.tokens,8);assert.deepEqual(s.content.dailyChallenge.cleared,[2]);assert.deepEqual(s.clearedStages,[]);
   await click(p,'도전 다시 출격');await p.waitForTimeout(400);s=await saved(p);assert.equal(s.content.dailyChallenge.tokens,8);assert.deepEqual(s.clearedStages,[]);await shot(p,`daily-victory-repeat-${w}`);
   rows.push({name:`daily-victory-settlement-fixture-${w}`,actualProfileSettlement:true,duplicateTierRewardBlocked:true,noCampaignAdvance:true,scope:'Finished/victory engine injected in QA entrypoint, not survival evidence'});await c.close();
  }
  {
   const {c,p}=await open(390,844,'http://127.0.0.1:8798/?scene=stress');const perf=await p.evaluate(()=>new Promise(resolve=>{const a=[];let prev=performance.now(),start=prev;function frame(now){a.push(now-prev);prev=now;if(now-start<2500)requestAnimationFrame(frame);else{a.sort((x,y)=>x-y);resolve({frames:a.length,p50:a[Math.floor(a.length*.5)],p95:a[Math.floor(a.length*.95)]});}}requestAnimationFrame(frame);}));await shot(p,'stress-450');rows.push({name:'450-enemy-render-fixture',...perf});await c.close();
  }
  assert.deepEqual(errors,[]);if(process.argv.includes('--fixtures-only')&&fs.existsSync(path.join(out,'browser-result.json'))){const old=JSON.parse(fs.readFileSync(path.join(out,'browser-result.json')));for(const r of old.rows)if(!rows.some(v=>v.name===r.name))rows.unshift(r);}
  fs.writeFileSync(path.join(out,'browser-result.json'),JSON.stringify({rows,errors,scope:'Local isolated guests and declared QA fixtures; original XAPK never executed; no production writes'},null,2));console.log(JSON.stringify({passed:rows.length,rows,errors},null,2));
 }catch(e){if(last&&!last.isClosed()){await shot(last,'failure');fs.writeFileSync(path.join(out,'failure-semantics.txt'),await last.locator('body').innerText());}throw e;}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});


