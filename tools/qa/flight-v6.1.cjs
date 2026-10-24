const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const out=path.join(__dirname,'evidence','flight-v6.1');fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const errors=[],rows=[];
 async function probe(page){
  const label=await page.locator('flt-semantics').evaluateAll(nodes=>nodes.map(e=>e.getAttribute('aria-label')||e.textContent).find(x=>x&&x.startsWith('probe ')));
  if(!label){fs.writeFileSync(path.join(out,'probe-aria.txt'),await page.locator('body').ariaSnapshot());throw new Error('Missing probe semantics');}
  return JSON.parse(label.slice(6,label.lastIndexOf('}')+1));
 }
 try{
  for(const mode of ['scout','weaver','bulwark','spitter','lancer','orbiter','miner','splitter','sniper','carrier','formation','ordnance']){
   const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
   const page=await context.newPage();page.on('pageerror',e=>errors.push(mode+': '+e.message));
   await page.clock.install();await page.goto('http://127.0.0.1:8796/?mode='+mode);
   await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
   await page.getByRole('button',{name:'계속 비행',exact:true}).waitFor();
   await page.clock.pauseAt(new Date(await page.evaluate(()=>Date.now())+500));
   await page.getByRole('button',{name:'계속 비행',exact:true}).click();
   const trace=[],kinds=new Set();let captured=false;
   const expected={scout:4,weaver:4,bulwark:21,spitter:22,lancer:20,orbiter:19,miner:17,splitter:4,sniper:23,carrier:20};
   for(let i=0;i<(mode==='formation'?10:48);i++){
    await page.clock.runFor(250);const state=await probe(page);trace.push(state);
    for(const shot of state.shots)kinds.add(shot.kind);
    if(!captured && state.shots.some(s=>s.kind===expected[mode])){await page.screenshot({path:path.join(out,mode+'-attack.png')});captured=true;}
    if(mode==='formation'&&i===1){
     await page.screenshot({path:path.join(out,'formation-line.png')});
     await page.getByRole('button',{name:'측면 회피',exact:true}).click();
    }
   }
   await page.screenshot({path:path.join(out,mode+'.png')});
   if(mode!=='formation'&&mode!=='ordnance'){
    const distances=trace.map(s=>s.foes[0].distance);
    assert(Math.min(...distances)>95,mode+': maintained safe distance');
    assert(['patrol','evade','windup'].includes(trace.at(-1).foes[0].state),mode+': established flight state');
   }
   if(expected[mode])assert(kinds.has(expected[mode]),mode+': visible weapon '+expected[mode]+' / '+[...kinds]);
   rows.push({mode,kinds:[...kinds],trace});fs.writeFileSync(path.join(out,'web-progress.json'),JSON.stringify({rows,errors},null,2));
   console.log('PASS',mode,[...kinds].join(','));await context.close();
  }
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'web-result.json'),JSON.stringify({rows,errors,scope:'Real renderer/engine; isolated high-hull visual fixture, no production save writes'},null,2));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
