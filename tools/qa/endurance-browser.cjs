// Desktop synthetic performance evidence, never a claim about mobile hardware.
const {chromium}=require('playwright'),fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.resolve(__dirname,'../..'),mode=process.env.QA_MODE||'soak';
const label=process.env.QA_LABEL||'after',seconds=Number(process.env.QA_SECONDS||(mode==='magnet'?35:600));
const out=path.join(root,'.local/endurance-v34');fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const errors=[],samples=[];let diagnostic;
 try{
  const c=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.abort());
  const p=await c.newPage();diagnostic=p;p.setDefaultTimeout(12000);p.on('pageerror',e=>errors.push(e.message));
  p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
  const session=await c.newCDPSession(p),cpu=Number(process.env.QA_CPU||1);
  await session.send('Emulation.setCPUThrottlingRate',{rate:cpu});
  await p.goto((process.env.QA_URL||'http://127.0.0.1:8799')+'/?mode='+mode+'&reference='+(label==='before'?'1':'0'));
  const stateLabel=()=>p.locator('[aria-label^="QA_ENDURANCE "]').last();
  const stateText=()=>p.getByText(/^QA_ENDURANCE /).last();
  let ready=false;
  for(let i=0;i<100;i++){
   const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());
   if((await stateLabel().count()||await stateText().count())&&(mode==='magnet'||await p.getByRole('button',{name:'일시정지',exact:true}).count())){ready=true;break;}
   await p.waitForTimeout(100);
  }
  assert(ready,'QA fixture did not expose its state');
  await p.waitForTimeout(3000);await session.send('HeapProfiler.collectGarbage');
  await p.evaluate(()=>{window.qaTimes=[];let last=performance.now();function tick(t){window.qaTimes.push(t-last);last=t;window.qaRaf=requestAnimationFrame(tick);}window.qaRaf=requestAnimationFrame(tick);});
  const started=Date.now(),interval=mode==='magnet'?5:30;
  for(let elapsed=0;elapsed<seconds;elapsed+=interval){
   await p.waitForTimeout(Math.min(interval,seconds-elapsed)*1000);
   const text=await stateLabel().count()?await stateLabel().getAttribute('aria-label'):await stateText().textContent();
   const state=JSON.parse(text.slice('QA_ENDURANCE '.length));
   const metrics=await p.evaluate(()=>{const a=window.qaTimes.splice(0).slice(1).sort((a,b)=>a-b),q=p=>a[Math.floor((a.length-1)*p)]||0;return{frames:a.length,p50:q(.5),p95:q(.95),p99:q(.99),max:a.at(-1)||0};});
   const gc=mode!=='magnet'&&(elapsed===0||elapsed+interval>=seconds||(elapsed+interval)%120===0);
   if(gc)await session.send('HeapProfiler.collectGarbage');
   const heap=await session.send('Runtime.getHeapUsage');
   samples.push({wallSeconds:(Date.now()-started)/1000,state,metrics,heap,gc});
   assert(state.checkpointBytes<2*1024*1024);assert(state.enemies<=260);assert(state.crystals<=1400);assert(state.motes<=1400);assert(state.cues<=80);assert(state.sparks<=161);assert(!state.finished);assert(!state.paused);assert.equal(state.saveFailures,0);assert.equal(state.restoreError,null);
   fs.writeFileSync(path.join(out,`${mode}-${label}.json`),JSON.stringify({label,mode,cpu,scope:mode==='magnet'?'Desktop Chrome fixed empty arena, production BattlePainter and actual magnet simulation; matched uncached/cached renderer branches, no profile checkpoint writes':'Desktop Chrome synthetic battle fixture and local checkpoints; invincible/perfect upgrades, no mobile hardware or user accounts',samples,errors},null,2));
   console.log(label,mode,'wall',samples.at(-1).wallSeconds.toFixed(1),'combat',state.combat.toFixed(1),'p95',metrics.p95.toFixed(1),'heap',Math.round(heap.usedSize/1048576));
  }
  await p.evaluate(()=>cancelAnimationFrame(window.qaRaf));
  fs.mkdirSync(path.join(__dirname,'evidence/endurance-v34'),{recursive:true});
  await p.screenshot({path:path.join(__dirname,`evidence/endurance-v34/${mode}-${label}.png`)});
  assert.deepEqual(errors,[]);
 }catch(error){
  if(diagnostic){await diagnostic.screenshot({path:path.join(out,`${mode}-${label}-failure.png`)});
   fs.writeFileSync(path.join(out,`${mode}-${label}-failure.json`),JSON.stringify({error:error.message,errors,accessibility:await diagnostic.locator('body').ariaSnapshot()},null,2));}
  throw error;
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
