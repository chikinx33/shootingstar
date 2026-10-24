// One short production-entrypoint check. No user profile or external writes.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const out=process.env.QA_EVIDENCE_DIR;
const version=process.env.QA_VERSION;
const {reveal}=require('./web-ui-navigation.cjs');
// Explicit 3 weapons x 4 mounts review, only when requested. Uses the regular
// release UI and real combat/checkpoints; all progress lives in fresh contexts.
async function reviewModulePlay(browser){
  fs.mkdirSync(out,{recursive:true});
  const results=[], errors=[];
  for(const part of ['gun_vulcan','missile_hawk','drone_wasp']){
    for(const mount of ['W1','W2','W3','W4']){
      const label=`${part}-${mount}`;
      if(process.env.QA_MODULE_REVIEW_CASES && !process.env.QA_MODULE_REVIEW_CASES.split(',').includes(label))continue;
      const fixture=JSON.parse(fs.readFileSync(path.join(process.env.QA_MODULE_REVIEW_FIXTURES,label+'.json'),'utf8'));
      const c=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true,
        recordVideo:{dir:path.join(out,'videos'),size:{width:390,height:844}}});
      await c.addInitScript(f=>localStorage.setItem('flutter.shootingstar.profile.v1',JSON.stringify(JSON.stringify(f))),fixture);
      await c.route('https://**',r=>r.abort());
      await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated review"}'}));
      const p=await c.newPage();p.setDefaultTimeout(10000);
      const tap=async l=>{const b=await reveal(p,l);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);};
      p.on('pageerror',e=>errors.push(label+': '+e.message));
      p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(label+': '+m.text());});
      try{
        await p.goto(process.env.QA_URL);
        for(let i=0;i<75;i++){
          const enable=p.locator('flt-semantics-placeholder');
          if(await enable.count())await enable.evaluate(e=>e.click());
          if(await p.getByRole('button',{name:'저장된 전투 이어하기',exact:true}).count())break;
          await p.waitForTimeout(150);
        }
        await tap(p.getByRole('button',{name:/^슬롯 표시/}));
        const name={W1:'날개끝',W2:'동체 하부',W3:'후미',W4:'상부'}[mount];
        const socket=p.getByRole('button',{name:`${mount} ${name} 모듈`,exact:true});
        await socket.waitFor();await tap(socket);
        const item=p.getByRole('button',{name:`review-${part} 파츠 특성`,exact:true});
        await item.waitFor();await p.waitForTimeout(350);await tap(item);
        await p.getByRole('heading',{name:'파츠 특성',exact:true}).waitFor();
        await p.waitForTimeout(400);
        if(process.env.QA_MODULE_REVIEW_ROLES==='1'){
          const text=await p.locator('body').ariaSnapshot();
          const role=part==='gun_vulcan'?'직선 관통·보스 정밀 · 조준 필요':'360° 회전 방공 · 짧은 사거리';
          assert(text.includes(role),label+' mount role missing');
          await p.screenshot({path:path.join(out,label+'-details.png')});
        }
        if(mount!=='W1'){
          const equip=p.getByRole('button',{name:'장착',exact:true});
          await tap(equip);await equip.waitFor({state:'hidden'});
        }else{
          await tap(p.getByRole('button',{name:'닫기',exact:true}).last());
        }
        await p.getByRole('heading',{name:'파츠 특성',exact:true}).waitFor({state:'hidden'});
        await p.waitForTimeout(500);
        await tap(p.getByRole('button',{name:'닫기',exact:true}).last());
        await p.getByRole('heading',{name:`${mount} · ${name}`,exact:true}).waitFor({state:'hidden'});
        await p.getByRole('button',{name:/^슬롯 숨기기/}).waitFor();
        await p.waitForTimeout(400);
        await tap(p.getByRole('button',{name:/^슬롯 숨기기/}));
        await tap(p.getByRole('button',{name:'저장된 전투 이어하기',exact:true}));
        await tap(p.getByRole('button',{name:'이전 전투 이어하기',exact:true}));
        const resume=p.getByRole('button',{name:'계속 비행',exact:true});
        await resume.waitFor();await tap(resume);
        const pause=p.getByRole('button',{name:/^일시정지/});await pause.waitFor();
        await p.mouse.move(195,480);await p.mouse.down();
        await p.waitForTimeout(1600);
        for(const x of [215,175,205,195]){
          await p.mouse.move(x,480,{steps:4});await p.waitForTimeout(400);
        }
        await p.screenshot({path:path.join(out,label+'.png')});
        await p.mouse.up();await tap(pause);
        await p.getByRole('button',{name:'계속 비행',exact:true}).waitFor();
        await p.waitForFunction(()=>{
          const p=JSON.parse(JSON.parse(localStorage.getItem('flutter.shootingstar.profile.v1')));
          return p._battle&&JSON.parse(p._battle.payload).state.paused;
        }).catch(()=>{}); // paused field is legacy-dependent; the forced write is awaited below.
        const saved=await p.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('flutter.shootingstar.profile.v1'))));
        const load=saved.moduleFleet.loadouts['0'];
        assert.equal(load[mount],'review-'+part,label+' UI mount');
        if(mount!=='W1')assert(!load.W1,label+' same instance moved, never copied');
        const game=JSON.parse(saved._battle.payload), damage=game.damage['part:'+mount+':'+part]||0;
        assert.equal(game.config.aircraft.modules.parts[mount].id,'review-'+part,label+' battle must match equipped part');
        assert(game.state.combatTime>=2,label+' real combat did not advance');
        assert(damage>0,label+' never dealt damage');
        results.push({part,mount,combatSeconds:game.state.combatTime,damage,
          screenshot:label+'.png',checkpointMatchesUi:game.config.aircraft.modules.parts[mount].id==='review-'+part});
        fs.writeFileSync(path.join(out,'module-play-review.partial.json'),JSON.stringify({version,results,errors},null,2));
        console.log('reviewed '+label+' damage='+damage.toFixed(1));
      }catch(e){
        await p.screenshot({path:path.join(out,label+'-failed.png')});
        fs.writeFileSync(path.join(out,label+'-failed.txt'),await p.locator('body').ariaSnapshot());
        throw e;
      }finally{
        const video=p.video();await c.close();
        if(video)fs.renameSync(await video.path(),path.join(out,'videos',label+'.webm'));
      }
    }
  }
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'module-play-review.json'),JSON.stringify({version,viewport:'390x844',
    actualUiMounting:true,actualPointerMovement:true,isolatedSavedEncounter:true,results,errors},null,2));
}
(async()=>{
  const browser=await chromium.launch({headless:true,
    executablePath:process.env.CHROME_PATH||'C:/Program Files/Google/Chrome/Application/chrome.exe'});
  const errors=[],started=Date.now();
  if(process.env.QA_MODULE_PLAY_REVIEW==='1'){
    try{await reviewModulePlay(browser);}finally{await browser.close();}
    return;
  }
  let motionFrames, activePage;
  try{
    const motion=process.env.QA_SMOKE_WEAPON_FEEDBACK==='1';
    if(motion)fs.mkdirSync(out,{recursive:true});
    const c=await browser.newContext({viewport:{width:320,height:568},isMobile:true,hasTouch:true});
    if(process.env.QA_INVENTORY_FIXTURE_PATH){
      const fixture=JSON.parse(fs.readFileSync(process.env.QA_INVENTORY_FIXTURE_PATH,'utf8'));
      await c.addInitScript(fixture=>localStorage.setItem('flutter.shootingstar.profile.v1',JSON.stringify(JSON.stringify(fixture))),fixture);
    }
    await c.route('https://**',r=>r.abort());
    await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated smoke"}'}));
    const p=await c.newPage();activePage=p;p.setDefaultTimeout(12000);
    const tap=async locator=>{const b=await reveal(p,locator);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);};
    p.on('pageerror',e=>errors.push(e.message));
    p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
    p.on('response',r=>{if(r.url().includes('/assets/')&&r.status()>=400)errors.push('asset '+r.status()+' '+r.url());});
    await p.goto(process.env.QA_URL);
    for(let i=0;i<75;i++){
      const placeholder=p.locator('flt-semantics-placeholder');
      if(await placeholder.count())await placeholder.evaluate(e=>e.click());
      // v11: a fresh profile opens the prologue first; skip it.
      const skip=p.getByRole('button',{name:'건너뛰기',exact:true});
      if(await skip.count()){await skip.click();await p.waitForTimeout(300);}
      // The loading HTML has a version; wait for the actual lobby controls.
      if(await p.getByRole('button',{name:'성장',exact:true}).count()
        && await p.getByRole('button',{name:/ · 출격$/}).count())break;
      await p.waitForTimeout(200);
    }
    // Wait for initial Korean font downloads before judging the painted frame.
    await p.waitForLoadState('networkidle');
    assert.equal(await p.getByText('v'+version,{exact:true}).count(),0,'lobby version footer must be absent');
    // Read the compiled version in the retained settings header instead.
    await tap(p.getByRole('button',{name:'설정',exact:true}).last());
    await p.getByRole('button',{name:'v'+version+' · 3초 눌러 개발자 인증',exact:true}).waitFor();
    await tap(p.getByRole('button',{name:'닫기',exact:true}).last());
    const navigation=p.getByRole('button',{name:'출격',exact:true});
    const before=await navigation.boundingBox();
    assert(before&&before.y+before.height>=567&&before.y+before.height<=568.5,'navigation must reach the bottom without a footer');
    const launch=p.getByRole('button',{name:/ · 출격$/}).first();
    const b=await launch.boundingBox();assert(b&&b.height>=72&&b.y+b.height<=568,'launch clipped');
    assert.equal(await p.evaluate(()=>document.documentElement.scrollHeight>innerHeight),false);
    await p.mouse.wheel(0,400);assert.deepEqual(await navigation.boundingBox(),before);
    fs.mkdirSync(out,{recursive:true});await p.screenshot({path:path.join(out,'lobby-320.png')});
    if(process.env.QA_SMOKE_MODULE_SYSTEM==='1'){
      await tap(p.getByRole('button',{name:/^슬롯 표시/}));
      await p.getByRole('button',{name:'W1 날개끝 모듈',exact:true}).waitFor();
      for(const name of ['W1 날개끝 모듈','W2 동체 하부 모듈','W3 후미 모듈','W4 상부 모듈',
        'S1 보조 슬롯','S2 보조 슬롯','S3 보조 슬롯'])
        assert.equal(await p.getByRole('button',{name,exact:true}).count(),1,name);
      await p.mouse.move(319,1);await p.screenshot({path:path.join(out,'module-slots-320.png')});
      await tap(p.getByRole('button',{name:'W1 날개끝 모듈',exact:true}));
      const part=p.getByRole('button',{name:/ 파츠 특성$/}).first();
      await part.waitFor();await tap(part);
      assert((await p.locator('body').ariaSnapshot()).includes('전방 ±15°'));
      // GameDialog paginates long numeric descriptions/actions on small screens.
      const equip=p.getByRole('button',{name:'장착',exact:true});
      await tap(equip);await equip.waitFor({state:'hidden'});
      await p.waitForTimeout(250);
      await tap(p.getByRole('button',{name:'닫기',exact:true}).last());
      await p.getByRole('button',{name:/^슬롯 숨기기/}).waitFor();
      await p.waitForTimeout(250);
      await tap(p.getByRole('button',{name:/^슬롯 숨기기/}));
      await p.getByRole('button',{name:'W1 날개끝 모듈',exact:true}).waitFor({state:'hidden'});
      await p.mouse.move(319,1);await p.screenshot({path:path.join(out,'module-complete-320.png')});
      assert.deepEqual(await navigation.boundingBox(),before);
    }
    if(process.env.QA_SMOKE_AIRCRAFT_SLOTS==='1'){
      await tap(p.getByRole('button',{name:'슬롯 표시',exact:true}));
      await p.getByRole('button',{name:'날개 슬롯',exact:true}).first().waitFor();
      assert.equal(await p.getByRole('button',{name:'슬롯 분류',exact:true}).count(),0);
      assert.equal(await p.getByRole('button',{name:'날개 슬롯',exact:true}).count(),2);
      for(const name of ['좌측 지원 슬롯','우측 지원 슬롯','후방 지원 슬롯'])
        assert.equal(await p.getByRole('button',{name,exact:true}).count(),1);
      await p.mouse.move(319,1);
      await p.screenshot({path:path.join(out,'aircraft-slots-before-320.png')});
      await tap(p.getByRole('button',{name:'주무장 슬롯',exact:true}));
      const choice=p.getByRole('button',{name:'주무장 슬롯 선택',exact:true});
      await choice.waitFor();
      await p.getByRole('button',{name:'주포 슬롯 선택',exact:true}).waitFor();
      await p.waitForTimeout(250);
      await p.screenshot({path:path.join(out,'slot-choices-320.png')});
      await tap(choice);
      await choice.waitFor({state:'hidden'});
      await p.waitForTimeout(250); // Finish the real dialog entrance before capture.
      const entries=await p.locator('body').ariaSnapshot();
      assert(entries.includes('유성 추적기'),'owned gear list missing');
      await p.screenshot({path:path.join(out,'owned-parts-320.png')});
      await tap(p.getByRole('button',{name:'유성 추적기 장비 특성',exact:true}));
      assert((await p.locator('body').ariaSnapshot()).includes('8회 사격마다 전방 유도 로켓'));
      await tap(p.getByRole('button',{name:'장착',exact:true}));
      await p.getByRole('button',{name:'장착',exact:true}).waitFor({state:'hidden'});
      await p.waitForTimeout(250); // Nested detail pop must finish before closing the list.
      await tap(p.getByRole('button',{name:'닫기',exact:true}).last());
      await p.getByRole('button',{name:'유성 추적기 장비 특성',exact:true}).waitFor({state:'hidden'});
      await p.waitForTimeout(250);
      await p.screenshot({path:path.join(out,'aircraft-slots-320.png')});
      await tap(p.getByRole('button',{name:'슬롯 숨기기',exact:true}));
      await p.getByRole('button',{name:'슬롯 표시',exact:true}).waitFor();
      assert.equal(await p.getByRole('button',{name:'주무장 슬롯',exact:true}).count(),0);
      assert.deepEqual(await navigation.boundingBox(),before);
      await p.screenshot({path:path.join(out,'aircraft-complete-320.png')});
    }
    if(process.env.QA_SMOKE_INVENTORY==='1'){
      await tap(p.getByRole('button',{name:'성장',exact:true}));
      await p.getByRole('checkbox',{name:'보관',exact:true}).waitFor();
      await tap(p.getByRole('checkbox',{name:'보관',exact:true}));
      await p.getByText(/인벤토리 .*\/240/).waitFor();
      await p.mouse.move(2,560);await p.waitForTimeout(150);
      await p.screenshot({path:path.join(out,'inventory-320.png')});
      await tap(p.getByRole('checkbox',{name:'주무장',exact:true}));
      await p.getByRole('button',{name:/^유성 추적기 .* 장비 /}).waitFor();
      await tap(p.getByRole('button',{name:/^유성 추적기 .* 장비 /}));
      await p.getByText('8회 사격마다 전방 유도 로켓 · 최대 3표적',{exact:true}).waitFor();
      await tap(p.getByRole('button',{name:'장비 상세 닫기',exact:true}));
      await tap(p.getByRole('button',{name:'출격',exact:true}));
    }
    await launch.click();
    // Complete the real first-run guide. It is one page on phones; reveal()
    // still follows page controls if a very small screen splits it.
    const done=p.getByRole('button',{name:'비행 준비 완료',exact:true});
    await done.or(p.getByRole('button',{name:/^다음 페이지/})).first().waitFor();
    await reveal(p,done);await done.click();
    const pause=p.getByRole('button',{name:'일시정지',exact:true});
    await pause.waitFor();
    if(motion){
      // Hold the actual touch field: releasing input deliberately uses 5% time.
      await p.mouse.move(160,350);await p.mouse.down();
      await p.mouse.move(170,350,{steps:3});await p.waitForTimeout(1100);
      if(process.env.QA_MOTION_PERF==='1'){
        motionFrames=await p.evaluate(()=>new Promise(resolve=>{
          let previous=0;const times=[];
          const tick=t=>{if(previous)times.push(t-previous);previous=t;
            if(times.length<180)requestAnimationFrame(tick);
            else{const sorted=[...times].sort((a,b)=>a-b);
              resolve({samples:times.length,medianMs:sorted[90],p95Ms:sorted[171],
                maxMs:sorted[179],over50Ms:times.filter(v=>v>50).length});}};
          requestAnimationFrame(tick);
        }));
      }
      for(let i=0;i<6;i++){
        await p.screenshot({path:path.join(out,`weapon-feedback-${i}.png`)});
        await p.waitForTimeout(40);
      }
      await p.mouse.up();
    }
    await pause.click();
    await p.getByRole('button',{name:'계속 비행',exact:true}).waitFor();
    await p.screenshot({path:path.join(out,'battle-paused-320.png')});
    assert.deepEqual(errors,[]);
    const result={version,width:320,height:568,textScale:1,lobbyVersionVisible:false,settingsVersionVisible:true,
      realOnboardingAndLaunch:true,pauseWorks:true,moduleSystemReviewed:process.env.QA_SMOKE_MODULE_SYSTEM==='1',aircraftSlotsReviewed:process.env.QA_SMOKE_AIRCRAFT_SLOTS==='1',weaponMotionRecorded:motion,motionFrames,inventoryReviewed:process.env.QA_SMOKE_INVENTORY==='1',isolatedInventoryFixture:!!process.env.QA_INVENTORY_FIXTURE_PATH,errors,seconds:(Date.now()-started)/1000};
    fs.writeFileSync(path.join(out,'smoke.json'),JSON.stringify(result,null,2));
    console.log(JSON.stringify(result));
  }catch(error){
    if(activePage){
      fs.mkdirSync(out,{recursive:true});
      await activePage.screenshot({path:path.join(out,'failed-320.png')}).catch(()=>{});
      fs.writeFileSync(path.join(out,'failed-semantics.txt'),await activePage.locator('body').ariaSnapshot().catch(()=>''));
    }
    throw error;
  }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
