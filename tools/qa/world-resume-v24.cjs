// Real main-entry resume uses a fresh browser context and isolated API replies.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','world-resume-v24');fs.mkdirSync(out,{recursive:true});
const button=(p,name)=>p.getByRole('button',typeof name==='string'?{name,exact:true}:{name}).last();
async function ready(p){
 for(let i=0;i<150;i++){
  const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());
  if(await button(p,'성장').count()||await button(p,'일시정지').count())break;
  await p.waitForTimeout(100);
 }
 await p.waitForLoadState('networkidle');
}
async function click(p,l){const b=await reveal(p,l);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(400);}
async function storage(p){return await p.evaluate(()=>{const v=JSON.parse(localStorage.getItem('flutter.shootingstar.profile.v1'));return typeof v==='string'?JSON.parse(v):v;});}
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const errors=[],results={version:'v10.0.24',errors,worlds:[]};
 const c=await browser.newContext({viewport:{width:320,height:568},isMobile:true,hasTouch:true});
 await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated QA"}'}));
 const p=await c.newPage();p.setDefaultTimeout(12000);
 p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
 try{
  await p.goto(process.env.QA_URL);await ready(p);await p.getByText('v10.0.24',{exact:true}).waitFor();
  await click(p,button(p,/ · 출격$/));await click(p,button(p,'비행 준비 완료'));
  await button(p,'일시정지').waitFor();
  const ultimate=await button(p,/^궁극기 충전/).boundingBox();assert(ultimate);
  const x=70,y=Math.max(250,ultimate.y-90);
  await p.mouse.move(x,y);await p.mouse.down();await p.waitForTimeout(1400);await p.mouse.up();await p.waitForTimeout(1000);
  const before=await storage(p);assert(before._battle,'active battle did not autosave');
  const saved=JSON.parse(before._battle.payload);assert(saved.state.elapsed>0);
  const runId=before._battle.runId;
  await p.reload();await ready(p);
  await click(p,button(p,'저장된 전투 이어하기'));
  await click(p,button(p,'이전 전투 이어하기'));
  await button(p,'계속 비행').waitFor();
  console.log('reloaded battle is paused');
  const restored=await storage(p);assert.equal(restored._battle.runId,runId);
  assert.equal(restored.credits,before.credits);assert.equal(restored.runs,before.runs);
  const recovered=JSON.parse(restored._battle.payload);
  assert(recovered.state.elapsed>=saved.state.elapsed && recovered.state.elapsed<=saved.state.elapsed+.5,'unload checkpoint should preserve the final active fraction');
  assert.equal(recovered.state.paused,true);assert.deepEqual(recovered.state.input,[0,0]);
  await p.waitForTimeout(500);assert.equal((await storage(p))._battle.payload,restored._battle.payload,'recovered battle must remain paused');
  await p.screenshot({path:path.join(out,'resume-after-reload-320.png')});
  await click(p,button(p,'저장 후 로비'));
  await button(p,'저장된 전투 이어하기').waitFor();
  const returned=await storage(p);assert.equal(returned._battle.runId,runId);assert.equal(returned.runs,0);assert.equal(returned.credits,before.credits);
  await click(p,button(p,'저장된 전투 이어하기'));
  await click(p,button(p,'이전 전투 포기'));
  await click(p,button(p,'이전 전투 유지'));
  await button(p,'저장된 전투 이어하기').waitFor();assert.equal((await storage(p))._battle.runId,runId);
  console.log('same run restored, saved to lobby and discard cancelled');
  results.resume={activeAutosave:true,reload:true,runIdPreserved:true,paused:true,saveAndReturn:true,cancelDiscard:true,noPayout:true,elapsed:saved.state.elapsed,bytes:JSON.stringify(returned).length};
  await c.close();
  if(process.env.WORLD_URL){
   const w=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
   await w.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{}'}));
   const q=await w.newPage();q.on('pageerror',e=>errors.push(e.message));q.setDefaultTimeout(10000);
   for(let world=0;world<10;world++){
    await q.goto(process.env.WORLD_URL+'/?world='+world+'&active=1');await ready(q);
    await q.getByLabel(/위험 ·/).waitFor();
    await q.screenshot({path:path.join(out,`world-${world}.png`)});results.worlds.push(world);console.log('world',world);
   }
   await w.close();
  }
  assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify(results,null,2));console.log('main-entry reload/resume and world scenes passed');
 }catch(e){if(!p.isClosed())await p.screenshot({path:path.join(out,'failure.png')});fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:e.message,errors},null,2));throw e;}
 finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
