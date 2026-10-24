// Production UI, isolated normal profile, all network writes intercepted.
const {chromium}=require('playwright'),fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const root=path.resolve(__dirname,'../..'),mode=process.env.QA_MODE||'flow',version=process.env.QA_VERSION||'10.0.34';
const out=path.join(__dirname,'evidence/endurance-v34'),samples=[],errors=[];
const raw=fs.readFileSync(path.join(root,`.local/endurance-v34/${mode}-profile.json`),'utf8');
(async()=>{
 fs.mkdirSync(out,{recursive:true});
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 let page;
 try{
  const c=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated production flow"}'}));
  await c.addInitScript(({raw})=>{
   if(!sessionStorage.getItem('endurance-seeded')){localStorage.setItem('flutter.shootingstar.profile.v1',JSON.stringify(raw));sessionStorage.setItem('endurance-seeded','1');}
   window.qaProfileWrites=0;const original=Storage.prototype.setItem;
   Storage.prototype.setItem=function(k,v){if(this===localStorage&&k==='flutter.shootingstar.profile.v1')window.qaProfileWrites++;return original.call(this,k,v);};
  },{raw});
  const p=await c.newPage();page=p;p.setDefaultTimeout(12000);
  p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
  const button=n=>p.getByRole('button',{name:n,exact:true}).last();
  const click=async n=>{await p.mouse.up();const b=await reveal(p,button(n));await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(300);};
  const read=()=>p.evaluate(()=>{let v=JSON.parse(localStorage.getItem('flutter.shootingstar.profile.v1'));return typeof v==='string'?JSON.parse(v):v;});
  const checkpoint=async()=>{const v=await read();return v._battle?JSON.parse(v._battle.payload):null;};
  const hold=async()=>{await p.mouse.up();await p.mouse.move(195,550);await p.mouse.down();};
  const ready=async()=>{for(let i=0;i<120;i++){const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());if(await button('성장').count()&&await p.getByText('v'+version,{exact:true}).count())return;await p.waitForTimeout(100);}throw Error('Production lobby/version unavailable');};
  const resume=async()=>{await click('저장된 전투 이어하기');await click('이전 전투 이어하기');await button('계속 비행').waitFor();};
  const choose=async()=>{const s=await checkpoint();if(!s?.choices.length)return false;
   await p.mouse.up();const selected=s.choices.find(c=>c.specialization)||s.choices[0];
   const name=selected.title.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
   const choice=p.getByRole('button',{name:new RegExp('^'+name)}).first();const b=await reveal(p,choice);
   await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(450);return true;};
  await p.goto('http://127.0.0.1:8797/?v='+version);await ready();await resume();
  if(mode==='flow'){
   await click('계속 비행');
   await p.waitForFunction(()=>{let v=JSON.parse(localStorage.getItem('flutter.shootingstar.profile.v1'));if(typeof v==='string')v=JSON.parse(v);return JSON.parse(v._battle.payload).choices.length>0;});
   assert(await choose());
   await p.waitForFunction(()=>{let v=JSON.parse(localStorage.getItem('flutter.shootingstar.profile.v1'));if(typeof v==='string')v=JSON.parse(v);const s=JSON.parse(v._battle.payload);return s.state.level===3&&s.choices.length>0;});
   await click('다시 뽑기 3회');await p.waitForTimeout(250);
   assert.equal((await checkpoint()).state.rerolls,2);
   await p.screenshot({path:path.join(out,'flow-growth-390.png')});assert(await choose());
   console.log('flow: actual growth and reroll passed');
   await click('일시정지');const paused=await checkpoint();
   await click('전투 통계');await click('통계 닫기');await p.waitForTimeout(500);
   assert.equal((await checkpoint()).state.combatTime,paused.state.combatTime);
   await click('저장 후 로비');await ready();const saved=await read();
   assert.equal(saved._battle.runId,'endurance-flow-v34');assert.equal(saved.credits,150);
   const branch=JSON.parse(saved._battle.payload).branch;
   assert(branch,'flow must select a real specialization before checking persistence');
   await p.reload();await ready();await resume();
   assert.equal((await checkpoint()).branch,branch);assert.deepEqual((await checkpoint()).state.input,[0,0]);
   await p.screenshot({path:path.join(out,'flow-resume-paused-390.png')});
   console.log('flow: pause/statistics/save/lobby/reload/resume passed');
   await click('계속 비행');await hold();let choices=2;
   for(let i=0;i<100;i++){
    await p.waitForTimeout(500);const current=await read();
    if(!current._battle&&current.runs===11)break;
    if(await choose()){choices++;await hold();}
   }
   await p.mouse.up();const settled=await read();assert.equal(settled.runs,11);assert(settled.clearedStages.includes(0));assert.equal(settled.selectedStage,1);assert(!settled._battle);
   assert(settled.credits>150);const earned=settled.credits;
   await p.waitForTimeout(1000);assert.equal((await read()).credits,earned);
   await p.screenshot({path:path.join(out,'flow-result-390.png')});await click('다음 항로 출격');
   await click('일시정지');assert.equal((await checkpoint()).config.stageIndex,1);
   const nextRunId=(await read())._battle.runId;
   await click('귀환 · 현재 보상 정산');await click('성장 정비 · 귀환');
   const returned=await read();assert.equal(returned.runs,11);assert(returned.processedRunIds.includes(nextRunId));assert.equal(returned.credits,earned);assert(!returned._battle);
   await p.screenshot({path:path.join(out,'flow-growth-return-390.png')});
   assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,'flow.json'),JSON.stringify({version:'v'+version,scope:'production entrypoint, synthetic late-run checkpoint with high hull/upgrades; actual input, growth, save, reward and route UI',choices,reroll:true,pauseStatisticsFrozen:true,saveLobbyReloadResume:true,branchPreserved:true,bossVictory:true,rewardOnce:true,nextRoute:true,abandonReturnToGrowth:true,credits:earned,errors},null,2));
   console.log('flow: boss/reward-once/next-route/abandon/growth-return passed');
  }else{
   await click('계속 비행');await hold();const session=await c.newCDPSession(p);
   await session.send('HeapProfiler.collectGarbage');
   await p.evaluate(()=>{window.qaTimes=[];let last=performance.now();function tick(t){window.qaTimes.push(t-last);last=t;window.qaRaf=requestAnimationFrame(tick);}window.qaRaf=requestAnimationFrame(tick);});
   const started=Date.now(),seconds=Number(process.env.QA_SECONDS||600);
   for(let elapsed=0;elapsed<seconds;elapsed+=30){
    await p.waitForTimeout(Math.min(30,seconds-elapsed)*1000);
    const v=await read(),s=JSON.parse(v._battle.payload),state=s.state;
    const gc=elapsed===0||elapsed+30>=seconds||(elapsed+30)%120===0;
    if(gc)await session.send('HeapProfiler.collectGarbage');
    const heap=await session.send('Runtime.getHeapUsage'),dom=await session.send('Memory.getDOMCounters');
    const frames=await p.evaluate(()=>{const a=window.qaTimes.splice(0).slice(1).sort((a,b)=>a-b),q=p=>a[Math.floor((a.length-1)*p)]||0;return{count:a.length,p50:q(.5),p95:q(.95),p99:q(.99),max:a.at(-1)||0,writes:window.qaProfileWrites};});
    assert.equal(v._battle.runId,'endurance-long-v34');assert.equal(v.credits,150);assert.equal(v.runs,10);assert(!state.paused);assert(!state.finished);
    assert(s.crystals.length<=1400);assert(s.absorption.length<=1400);assert(s.enemies.length<=260);assert(s.shots.length<1000);assert(Buffer.byteLength(v._battle.payload)<2*1024*1024);
    samples.push({wallSeconds:(Date.now()-started)/1000,combatSeconds:state.combatTime,chapterSeconds:state.elapsed,crystals:s.crystals.length,motes:s.absorption.length,enemies:s.enemies.length,shots:s.shots.length,checkpointBytes:Buffer.byteLength(v._battle.payload),heap,dom,frames,gc});
    fs.writeFileSync(path.join(out,'production-soak.json'),JSON.stringify({version:'v'+version,scope:'real-time desktop Chrome on production UI/normal guest profile, high-hull long-boss fixture, pointer held; no phone/thermal claim',samples,errors},null,2));
    console.log('production soak',samples.at(-1).wallSeconds.toFixed(1),'combat',state.combatTime.toFixed(1),'p95',frames.p95.toFixed(1),'writes',frames.writes,'heapMB',Math.round(heap.usedSize/1048576));
   }
   await p.mouse.up();await click('일시정지');await click('저장 후 로비');await ready();
   const before=await checkpoint();await p.reload();await ready();await resume();
   const after=await checkpoint();assert.equal(after.state.combatTime,before.state.combatTime);assert.deepEqual(after.state.input,[0,0]);
   await p.screenshot({path:path.join(out,'long-resume-paused-390.png')});assert.deepEqual(errors,[]);
   const report={version:'v'+version,scope:'real-time desktop Chrome on production UI/normal guest profile; synthetic high hull/held boss, no mobile or natural win-rate claim',samples,restoredPausedAfterSoak:true,progressAndCreditsUnsettled:true,errors};
   fs.writeFileSync(path.join(out,'production-soak.json'),JSON.stringify(report,null,2));
  }
 }catch(error){if(page){await page.screenshot({path:path.join(out,`${mode}-failure.png`)});fs.writeFileSync(path.join(out,`${mode}-failure.json`),JSON.stringify({error:error.message,accessibility:await page.locator('body').ariaSnapshot(),errors},null,2));}throw error;}
 finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
