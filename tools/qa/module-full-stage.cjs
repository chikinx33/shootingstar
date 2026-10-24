// Real production entrypoint: fresh guest, no battle fixture, clock override,
// developer mode or injected upgrades. Read only its own periodic checkpoint;
// all movement, cards and ultimate activation use ordinary UI inputs.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const version=process.env.QA_VERSION||'10.0.69';
const out=process.env.QA_EVIDENCE_DIR||path.join(__dirname,'evidence','module-run-v69');
const norm=v=>{const d=Math.hypot(...v);return d>1?v.map(x=>x/d):v;};
const distance=(a,b)=>Math.hypot(a[0]-b[0],a[1]-b[1]);
const escape=s=>s.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
function score(c,g){
  const s=g.state;
  if(c.id==='repair')return s.hp<s.maxHp*.6?130:-1;
  if(c.id==='hull'&&s.hp<s.maxHp*.8)return 120;
  if(c.id.startsWith('part:'))return 95-(g.upgrades[c.id]||0)*4;
  return ({attack:88,gun:85,cooldown:83,magnet:78,hull:70})[c.id]||60;
}
function steer(g,at,time,age){
  const foes=g.enemies.map(i=>g.foes[i]).filter(e=>e&&e.hp>0&&!e.retired);
  const boss=foes.find(e=>e.kind===3);
  let goal=boss?[boss.position[0]+90*Math.sin(time*.6),boss.position[1]+175]:
    [900+140*Math.sin(time*.23),1200+150*Math.cos(time*.23)];
  if(!boss){
    let nearest=200;
    const repair=g.supplies.filter(s=>s.kind===0).sort((a,b)=>distance(a.p,at)-distance(b.p,at))[0];
    const items=[...g.crystals,...g.supplies.filter(s=>s.kind!==0||g.state.hp<g.state.maxHp*.85).map(s=>s.p)].filter(item=>distance(item,at)>50);
    for(const item of items){const d=distance(item,at);if(d<nearest){nearest=d;goal=item;}}
    if(repair&&g.state.hp<g.state.maxHp*.8&&distance(repair.p,at)<360&&distance(repair.p,at)>35)goal=repair.p;
  }
  if(process.env.QA_RUN_POLICY==='circle'){
    if(boss)return [Math.sin(time*2.8)>0?1:-1,0];
    return [Math.cos(time*.8),Math.sin(time*.8)];
  }
  if(process.env.QA_RUN_POLICY==='sweep'&&!boss)return norm([goal[0]-at[0],goal[1]-at[1]]);
  let best=[0,0],bestScore=-Infinity;
  for(let i=0;i<16;i++){
    const direction=[Math.cos(i*Math.PI/8),Math.sin(i*Math.PI/8)];
    const point=at.map((x,j)=>x+direction[j]*65);
    if(point[0]<40||point[0]>1760||point[1]<40||point[1]>2360)continue;
    let value=-distance(point,goal)*.03;
    for(const shot of g.shots.filter(s=>[4,17,19,20,21,22,23,24].includes(s.kind)&&s.life>age)){
      if(shot.kind===23)continue; // First route uses volley/fan/charge.
      for(const horizon of [0,.3,.6]){
        const p=shot.position.map((x,j)=>x+shot.velocity[j]*(age+horizon));
        value-=Math.max(0,42+shot.radius-distance(point,p))*.7;
      }
    }
    for(const foe of foes.filter(e=>e.plane==='air'))
      value-=Math.max(0,foe.radius+40-distance(point,foe.position))*.4;
    if(value>bestScore){bestScore=value;best=direction;}
  }
  return best;
}
(async()=>{
  fs.mkdirSync(out,{recursive:true});
  const browser=await chromium.launch({headless:true,
    executablePath:process.env.CHROME_PATH||'C:/Program Files/Google/Chrome/Application/chrome.exe'});
  const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true,
    recordVideo:{dir:path.join(out,'videos'),size:{width:390,height:844}}});
  await context.route('https://**',r=>r.abort());
  await context.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated full run"}'}));
  const p=await context.newPage(),errors=[],drafts=[],samples=[];p.setDefaultTimeout(10000);
  p.on('pageerror',e=>errors.push(e.message));
  p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
  const tap=async l=>{const b=await reveal(p,l);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);};
  const held=new Set();
  async function keys(next,force=false){
    for(const k of [...held])if(force||!next.includes(k)){await p.keyboard.up(k);held.delete(k);}
    for(const k of next)if(!held.has(k)){await p.keyboard.down(k);held.add(k);}
  }
  let finalProfile,lastGame,wallStart=Date.now(),bossSeen=false,won=false;
  try{
    await p.goto(process.env.QA_URL||`http://127.0.0.1:8797/?v=${version}`);
    for(let i=0;i<80;i++){
      const enable=p.locator('flt-semantics-placeholder');if(await enable.count())await enable.evaluate(e=>e.click());
      if(await p.getByRole('button',{name:/ · 출격$/}).count())break;
      await p.waitForTimeout(150);
    }
    await tap(p.getByRole('button',{name:/ · 출격$/}).first());
    const ready=p.getByRole('button',{name:'비행 준비 완료',exact:true});
    await reveal(p,ready);await ready.click();
    await p.getByRole('button',{name:'일시정지',exact:true}).waitFor();
    await p.screenshot({path:path.join(out,'stage-start.png')});
    // Keep a stationary touch held to retain normal speed when keyboard stops.
    await p.mouse.move(195,560);await p.mouse.down();
    wallStart=Date.now();
    let lastProgress=Date.now(),lastTime=-1,readAt=Date.now(),estimate=[900,1200],tickAt=Date.now(),lastSample=-20;
    for(let iteration=0;Date.now()-wallStart<480000;iteration++){
      finalProfile=await p.evaluate(()=>{
        const raw=localStorage.getItem('flutter.shootingstar.profile.v1');
        return raw?JSON.parse(JSON.parse(raw)):null;
      });
      if(finalProfile?._battle){
        const g=JSON.parse(finalProfile._battle.payload);lastGame=g;
        const now=Date.now(),s=g.state;
        if(s.combatTime!==lastTime){lastTime=s.combatTime;readAt=now;lastProgress=now;estimate=[...s.position];}
        else{
          const step=(now-tickAt)/1000,velocity=norm([
            (held.has('ArrowRight')?1:0)-(held.has('ArrowLeft')?1:0),
            (held.has('ArrowDown')?1:0)-(held.has('ArrowUp')?1:0)]);
          estimate=estimate.map((x,j)=>Math.max(32,Math.min(j?2368:1768,x+velocity[j]*200*(1+(g.passives.speed||0)*.08)*step)));
        }
        tickAt=now;
        if(g.choices.length){
          const choices=[...g.choices].sort((a,b)=>score(b,g)-score(a,g));
          const item=p.getByRole('button',{name:new RegExp('^'+escape(choices[0].title))}).first();
          if(await item.count()){
            await keys([]);await p.mouse.up();await p.waitForTimeout(450);await tap(item);
            drafts.push({time:s.combatTime,level:s.level,id:choices[0].id});
            if(drafts.length===1)await p.screenshot({path:path.join(out,'first-draft.png')});
            await p.waitForTimeout(450);
            await p.mouse.move(195,560);await p.mouse.down();
            await keys([],true);tickAt=Date.now();
          }
        }else{
          const direction=steer(g,estimate,s.combatTime,Math.min(2,(now-readAt)/1000));
          const next=[];
          if(Math.abs(direction[0])>.3)next.push(direction[0]>0?'ArrowRight':'ArrowLeft');
          if(Math.abs(direction[1])>.3)next.push(direction[1]>0?'ArrowDown':'ArrowUp');
          await keys(next);
          if(s._ultimateCharge>=100){await p.keyboard.press('Space');}
        }
        const boss=g.enemies.map(i=>g.foes[i]).find(e=>e.kind===3&&e.hp>0);
        if(boss&&!bossSeen){bossSeen=true;await p.screenshot({path:path.join(out,'boss-start.png')});}
        if(s.combatTime-lastSample>=20){
          samples.push({time:s.combatTime,elapsed:s.elapsed,hp:s.hp,level:s.level,bossHp:boss?.hp});
          lastSample=s.combatTime;
          console.log(JSON.stringify(samples[samples.length-1]));
          fs.writeFileSync(path.join(out,'partial.json'),JSON.stringify({version,drafts,samples,errors},null,2));
        }
      }
      if(iteration%4===0){
        const snapshot=await p.locator('body').ariaSnapshot();
        if(/집을 지켜 냈다냥!|항로 돌파|항로 완주|임무 완료|비행 완료/.test(snapshot)){
          won=true;fs.writeFileSync(path.join(out,'result-aria.txt'),snapshot);break;
        }
        if(/다음엔 꼭 이긴다냥|격추|다시 출격|전투 패배/.test(snapshot)){
          fs.writeFileSync(path.join(out,'result-aria.txt'),snapshot);break;
        }
      }
      if(Date.now()-lastProgress>15000){
        fs.writeFileSync(path.join(out,'stalled-aria.txt'),await p.locator('body').ariaSnapshot());
        await p.screenshot({path:path.join(out,'stalled.png')});break;
      }
      await p.waitForTimeout(180);
    }
    await keys([]);await p.mouse.up();
    const result=await p.locator('body').ariaSnapshot();
    fs.writeFileSync(path.join(out,'result-aria.txt'),result);
    await p.screenshot({path:path.join(out,'stage-result.png')});
    // Result UI is authoritative; profile history is retained as independent proof.
    finalProfile=await p.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('flutter.shootingstar.profile.v1'))));
    fs.writeFileSync(path.join(out,'profile-at-result.json'),JSON.stringify(finalProfile));
    fs.writeFileSync(path.join(out,'full-stage.json'),JSON.stringify({version,wallSeconds:(Date.now()-wallStart)/1000,
      freshGuest:true,battleFixture:false,speedOverride:false,normalHull:true,actualUiInputs:true,
      won,bossSeen,drafts,samples,lastBattle:lastGame,errors},null,2));
    assert.deepEqual(errors,[]);assert(bossSeen,'boss never reached');assert(won,'did not clear the stage');
    console.log('PASS fresh production stage from lobby through natural growth to boss defeat');
  }finally{
    const video=p.video();await context.close();
    if(video)fs.renameSync(await video.path(),path.join(out,'videos','full-stage.webm'));
    await browser.close();
  }
})().catch(e=>{console.error(e);process.exitCode=1;});
