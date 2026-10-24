// Inspect the actual release UI using isolated local resume fixtures.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out='tools/qa/evidence/run-v62/web';
(async()=>{
  fs.mkdirSync(out,{recursive:true});
  const browser=await chromium.launch({headless:true,
    executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
  const results=[];
  try {
    for(const world of [0,5]) {
      const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
      const fixture=JSON.parse(fs.readFileSync(`.local/run-v62/web-fixtures/world-${world}.json`,'utf8'));
      await context.addInitScript(data=>localStorage.setItem('flutter.shootingstar.profile.v1',
        JSON.stringify(JSON.stringify(data))),fixture);
      await context.route('https://**',r=>r.abort());
      await context.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated QA"}'}));
      const p=await context.newPage(),errors=[],cues=new Set();
      p.setDefaultTimeout(12000);
      p.on('pageerror',e=>errors.push(e.message));
      p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
      await p.goto('http://127.0.0.1:8797/?v=10.0.62');
      for(let i=0;i<80;i++) {
        const placeholder=p.locator('flt-semantics-placeholder');
        if(await placeholder.count())await placeholder.evaluate(e=>e.click());
        if(await p.getByRole('button',{name:'저장된 전투 이어하기',exact:true}).count())break;
        await p.waitForTimeout(150);
      }
      await p.getByRole('button',{name:'저장된 전투 이어하기',exact:true}).click();
      const previous=p.getByRole('button',{name:'이전 전투 이어하기',exact:true});
      const box=await reveal(p,previous);
      await p.mouse.click(box.x+box.width/2,box.y+box.height/2);
      await p.getByRole('button',{name:'계속 비행',exact:true}).click();
      await p.mouse.move(195,550);await p.mouse.down(); // Held, stationary = 100% time.
      const initial=await p.locator('body').ariaSnapshot();
      for(let i=0;i<(world===0?30:10);i++) {
        if(world===0) {
          const key=i%4<2?'ArrowLeft':'ArrowRight';
          await p.keyboard.down(key);await p.waitForTimeout(400);await p.keyboard.up(key);
        } else await p.waitForTimeout(400);
        const snapshot=await p.locator('body').ariaSnapshot();
        const texts=snapshot.split('\n').filter(t=>/보스.*단계|방사 예고|조준 고정|돌진 예고|코어 개방|압축 기뢰|재정렬/.test(t));
        texts.forEach(t=>cues.add(t));
        if(i===(world===0?6:4))await p.screenshot({path:path.join(out,`world-${world}-active.png`)});
      }
      await p.mouse.up();
      const pause=p.getByRole('button',{name:'일시정지',exact:true});
      if(await pause.count()) {
        await pause.click();
        await p.getByRole('button',{name:'계속 비행',exact:true}).waitFor();
      }
      const final=await p.locator('body').ariaSnapshot();
      await p.screenshot({path:path.join(out,`world-${world}-paused.png`)});
      assert.deepEqual(errors,[]);
      assert(cues.size>0,'boss cue missing');
      results.push({world,version:'10.0.62',isolatedResumeFixture:true,
        naturalBuildAcquisition:world===0,invincible:false,cues:[...cues],initial,final,errors});
      await context.close();
    }
    fs.writeFileSync(path.join(out,'play.json'),JSON.stringify(results,null,2));
    console.log(JSON.stringify(results.map(({world,cues,errors})=>({world,cues,errors}))));
  } finally { await browser.close(); }
})().catch(e=>{console.error(e);process.exit(1);});
