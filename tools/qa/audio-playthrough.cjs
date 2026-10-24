const {chromium}=require('playwright'),fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs'),{installMeter}=require('./audio-mix-meter.cjs');
const root=path.resolve(__dirname,'../..'),version=process.env.QA_VERSION||'10.0.35',tag=process.env.QA_TAG||'before';
const out=path.join(__dirname,'evidence/audio-v36');fs.mkdirSync(out,{recursive:true});
const seed=JSON.parse(fs.readFileSync(path.join(root,'.local/endurance-v34/flow-profile.json'),'utf8'));
seed.soundEnabled=true;seed.volume=1;seed.onboarded=true;
const errors=[],checks=[];
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});let p;
 try{
  const c=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated audio playthrough"}'}));
  await c.addInitScript(seed=>{if(!sessionStorage.getItem('mix-seed')){localStorage.setItem('flutter.shootingstar.profile.v1',JSON.stringify(JSON.stringify(seed)));sessionStorage.setItem('mix-seed','1');}},seed);
  await c.addInitScript(installMeter);p=await c.newPage();p.setDefaultTimeout(12000);
  p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by|NotAllowedError|AudioPlayerException/.test(m.text()))errors.push(m.text());});
  const button=n=>p.getByRole('button',{name:n,exact:true}).last();
  const clickL=async(l,settle=200)=>{await p.mouse.up();const b=await reveal(p,l);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(settle);};
  const click=n=>clickL(button(n));
  const read=()=>p.evaluate(()=>{let v=JSON.parse(localStorage.getItem('flutter.shootingstar.profile.v1'));return typeof v==='string'?JSON.parse(v):v;});
  const checkpoint=async()=>{const s=await read();return s._battle?JSON.parse(s._battle.payload):null;};
  const report=async name=>{const r=await p.evaluate(()=>window.mixReport());fs.writeFileSync(path.join(out,`${tag}-${name}.json`),JSON.stringify(r));checks.push({name,events:r.events.length,contexts:r.contexts});return r;};
  const ready=async()=>{for(let i=0;i<100;i++){const q=p.locator('flt-semantics-placeholder');if(await q.count())await q.evaluate(e=>e.click());if(await button('성장').count()&&await p.getByText('v'+version,{exact:true}).count())return;await p.waitForTimeout(150);}throw Error('lobby not ready');};
  const hold=async()=>{await p.mouse.move(195,520);await p.mouse.down();};
  const choose=async()=>{const state=await checkpoint();if(!state?.choices.length)return false;await p.mouse.up();const choice=state.choices.find(c=>c.specialization)||state.choices[0];await clickL(p.getByRole('button',{name:new RegExp('^'+choice.title)}).first());await p.waitForTimeout(300);return true;};
  await p.goto('http://127.0.0.1:8797/?v='+version);await ready();
  await click('성장');await p.waitForTimeout(1200);await p.evaluate(()=>window.mixMark());
  if(!process.env.QA_SETTINGS_ONLY){
  for(const name of ['연구','성장','보급','출격','성장','출격'])await click(name);
  await p.waitForTimeout(2500);await report('lobby');
  await p.evaluate(()=>window.mixMark());await click('저장된 전투 이어하기');await click('이전 전투 이어하기');await button('계속 비행').waitFor();
  await p.waitForTimeout(500);const restored=await report('restored-paused');
  assert(!restored.applicationMedia.some(m=>m.loop),'restored paused battle must stay quiet');
  await p.evaluate(()=>window.mixMark());await click('계속 비행');
  for(let i=0;i<80;i++){
   await p.waitForTimeout(400);if(await choose())await hold();
   else if(await button('일시정지').count())await hold();
   const state=await read();if(!state._battle&&state.runs===11)break;
  }
  await p.mouse.up();const settled=await read();assert.equal(settled.runs,11,'real boss/result settlement');
  const battle=await report('battle-victory');assert(battle.events.some(e=>e.file==='victory.wav'));
  await p.waitForTimeout(1400);const result=await report('result');assert(!result.applicationMedia.some(m=>m.loop));
  await p.evaluate(()=>window.mixMark());await click('다음 항로 출격');await hold();await p.waitForTimeout(1400);await p.mouse.up();
  await click('일시정지');await p.waitForTimeout(800);const paused=await report('paused');assert(!paused.applicationMedia.some(m=>m.loop));
  await click('계속 비행');await hold();await p.waitForTimeout(900);await p.mouse.up();
  await click('일시정지');await click('저장 후 로비');await ready();await p.waitForTimeout(1200);
  const returned=await report('returned');assert(returned.applicationMedia.some(m=>m.file==='lobby-groove.wav'&&m.loop));assert(!returned.applicationMedia.some(m=>m.file==='battle-drive.wav'));
  }
  if(process.env.QA_SETTINGS_ONLY){
   await click('설정');for(let i=0;i<5;i++)await click('음량 줄이기');
   assert(Math.abs((await read()).volume-.5)<.001);
   const volume=await report('volume-half');
   const music=volume.samples.at(-1).voices.find(v=>v.loop);assert(music&&Math.abs(music.gain-.22)<.002);
   const toggle=p.getByRole('switch',{name:'음악·효과음',exact:true}).first();
   await clickL(toggle,300);let muted=await report('muted');assert.equal(muted.applicationMedia.length,0);
   // Re-enable then mute while the 140ms fade is still in flight.
   await clickL(toggle,30);await clickL(toggle,300);
   muted=await report('mute-during-fade');assert.equal((await read()).soundEnabled,false);assert.equal(muted.applicationMedia.length,0);
   await clickL(toggle,300);await click('닫기');
   const restored=await report('settings-return');assert(restored.applicationMedia.some(m=>m.loop&&m.file==='lobby-groove.wav'));
  }
  await p.screenshot({path:path.join(out,`${tag}-lobby.png`)});
  assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,`${tag}-checks.json`),JSON.stringify({version,checks,errors},null,2));console.log(tag,'playthrough passed',checks);
 }catch(e){if(p){await p.screenshot({path:path.join(out,`${tag}-failure.png`)});fs.writeFileSync(path.join(out,`${tag}-failure.json`),JSON.stringify({error:e.message,errors,checks,aria:await p.locator('body').ariaSnapshot()},null,2));fs.writeFileSync(path.join(out,`${tag}-failure-meter.json`),JSON.stringify(await p.evaluate(()=>window.mixReport())));}throw e;}
 finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
