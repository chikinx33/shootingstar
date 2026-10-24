// Real production entrypoint / real media graph, isolated guest storage + API.
// No autoplay-policy bypass, no fake AudioPlayer and no writes to real accounts.
const {chromium}=require('playwright'),fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const root=path.resolve(__dirname,'../..'),out=path.join(__dirname,'evidence/audio-v35');
const seed=JSON.parse(fs.readFileSync(path.join(root,'.local/endurance-v34/flow-profile.json'),'utf8'));
delete seed._battle;seed.soundEnabled=true;seed.volume=.6;seed.onboarded=true;seed.credits=6000;seed.blueprints=100;
const errors=[],stages=[];
(async()=>{
 fs.mkdirSync(out,{recursive:true});
 const b=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 let p;
 try{
  const c=await b.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  await c.route('https://**',r=>r.abort());
  await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated audio QA"}'}));
  await c.addInitScript(seed=>{
   localStorage.setItem('flutter.shootingstar.profile.v1',JSON.stringify(JSON.stringify(seed)));
   const contexts=[],media=new Set(),gains=[],events=[];
   const native=window.AudioContext;
   window.AudioContext=new Proxy(native,{construct(Target,args){const ctx=Reflect.construct(Target,args);contexts.push(ctx);return ctx;}});
   const source=native.prototype.createMediaElementSource;
   native.prototype.createMediaElementSource=function(el){media.add(el);return source.call(this,el);};
   const gain=native.prototype.createGain;
   native.prototype.createGain=function(){const node=gain.call(this),analyser=this.createAnalyser();node.connect(analyser);gains.push({node,analyser,context:this});return node;};
   const play=HTMLMediaElement.prototype.play;
   HTMLMediaElement.prototype.play=function(){const el=this;return play.call(this).then(v=>{events.push({file:el.src.split('/').pop(),src:el.src,loop:el.loop,at:performance.now()});return v;});};
   window.audioSnapshot=()=>({
    contexts:contexts.map(c=>c.state),
    media:[...media].map(el=>({file:el.src.split('/').pop(),src:el.src,loop:el.loop,paused:el.paused,ended:el.ended,time:el.currentTime})).filter(el=>el.src&&!el.src.endsWith('/')),
    gains:gains.map(({node,analyser,context})=>{const data=new Float32Array(analyser.fftSize);analyser.getFloatTimeDomainData(data);return {state:context.state,gain:node.gain.value,rms:Math.sqrt(data.reduce((a,x)=>a+x*x,0)/data.length)};}),
    events:events.slice(-300),totalEvents:events.length,
   });
  },seed);
  p=await c.newPage();p.setDefaultTimeout(12000);
  p.on('pageerror',e=>errors.push(e.message));
  p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by|NotAllowedError|AudioPlayerException/.test(m.text()))errors.push(m.text());});
  p.on('response',r=>{if(r.url().includes('/audio/')&&r.status()>=400)errors.push('audio HTTP '+r.status()+' '+r.url());});
  const button=n=>p.getByRole('button',{name:n,exact:true}).last();
  const clickLocator=async l=>{await p.mouse.up();const box=await reveal(p,l);await p.mouse.click(box.x+box.width/2,box.y+box.height/2);await p.waitForTimeout(220);};
  const click=n=>clickLocator(button(n));
  const snap=async name=>{const s=await p.evaluate(()=>window.audioSnapshot());stages.push({name,...s});return s;};
  const playing=(s,track)=>s.media.filter(m=>m.loop&&!m.paused&&m.src.includes(track));
  const waitTrack=async track=>{await p.waitForFunction(track=>window.audioSnapshot().media.some(m=>m.loop&&!m.paused&&m.src.includes(track)),track);};
  const quiet=async()=>{await p.waitForFunction(()=>window.audioSnapshot().media.every(m=>m.paused||m.ended));};
  const read=()=>p.evaluate(()=>{let v=JSON.parse(localStorage.getItem('flutter.shootingstar.profile.v1'));return typeof v==='string'?JSON.parse(v):v;});
  await p.goto('http://127.0.0.1:8797/?v=10.0.35');
  for(let i=0;i<100;i++){
   const q=p.locator('flt-semantics-placeholder');if(await q.count())await q.evaluate(e=>e.click());
   if(await button('성장').count()&&await p.getByText('v10.0.35',{exact:true}).count())break;
   await p.waitForTimeout(150);
  }
  assert.equal((await snap('before-first-gesture')).media.filter(m=>!m.paused).length,0);
  await click('성장');await waitTrack('lobby-groove');await p.waitForTimeout(800);
  let s=await snap('lobby-unlocked');assert.equal(playing(s,'lobby-groove').length,1);assert(s.gains.some(g=>g.rms>.001));
  await click('설정');await clickLocator(p.getByRole('switch',{name:'음악·효과음',exact:true}).first());await quiet();
  assert.equal((await read()).soundEnabled,false);await snap('muted');
  await clickLocator(p.getByRole('switch',{name:'음악·효과음',exact:true}).first());await waitTrack('lobby-groove');
  await click('음량 높이기');assert(Math.abs((await read()).volume-.7)<.001);
  await click('닫기');await click('보급');await click('장비 보급 상세');await click('장비 보급 열기');
  await p.waitForTimeout(400);s=await snap('reward');assert(s.events.some(e=>e.src.includes('/reward.ogg')));
  await click('확인');await click('닫기');await click('출격');
  const launch=p.getByRole('button',{name:/ · 출격$/}).first();await clickLocator(launch);
  await button('일시정지').waitFor();await waitTrack('battle-drive');
  await p.mouse.move(195,510);await p.mouse.down();await p.waitForTimeout(6500);await p.mouse.up();
  s=await snap('battle-playing');assert.equal(playing(s,'battle-drive').length,1);assert.equal(playing(s,'lobby-groove').length,0);
  assert(s.events.some(e=>e.src.includes('/weapon-')));assert(s.gains.some(g=>g.rms>.001));
  // Let a real loop boundary pass; the HTML loop remains on the same media.
  const start=s.media.find(m=>m.loop&&!m.paused&&m.src.includes('battle-drive'));
  await p.waitForTimeout(30000);
  s=await snap('battle-loop-and-voices');assert.equal(playing(s,'battle-drive').length,1);
  assert(s.contexts.length<=7,'music plus six pooled effect contexts');
  assert(s.media.filter(m=>!m.paused&&!m.ended).length<=7);
  assert(s.media.some(m=>m.loop&&!m.paused&&m.src===start.src));
  await click('일시정지');await p.waitForTimeout(600);await quiet();await snap('paused');
  await click('계속 비행');await waitTrack('battle-drive');await snap('resumed');
  await click('일시정지');await click('저장 후 로비');await waitTrack('lobby-groove');
  s=await snap('returned-lobby');assert.equal(playing(s,'battle-drive').length,0);
  await p.screenshot({path:path.join(out,'lobby-390.png')});
  assert.deepEqual(errors,[]);
  const report={version:'v10.0.35',scope:'desktop Chrome production UI and real WebAudio graph; no physical-device or subjective listening claim',stages,errors};
  fs.writeFileSync(path.join(out,'browser.json'),JSON.stringify(report,null,2));console.log('Audio browser checks passed:',stages.map(s=>s.name).join(', '));
 }catch(e){if(p){await p.screenshot({path:path.join(out,'failure.png')});fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:e.message,errors,stages,aria:await p.locator('body').ariaSnapshot()},null,2));}throw e;}
 finally{await b.close();}
})().catch(e=>{console.error(e);process.exit(1)});
