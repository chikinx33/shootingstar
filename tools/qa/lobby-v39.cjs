// Production entrypoint: compare the moving scenery with fixed controls.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
(async()=>{
  const out=path.resolve('tools/qa/evidence/lobby-v39');fs.mkdirSync(out,{recursive:true});
  const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
  const errors=[];
  try{
    const c=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
    await c.route('https://**',r=>r.abort());
    await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated motion QA"}'}));
    const p=await c.newPage();p.setDefaultTimeout(12000);
    p.on('pageerror',e=>errors.push(e.message));
    p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
    const tap=async locator=>{const b=await reveal(p,locator);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);};
    await p.goto('http://127.0.0.1:8797/?v=10.0.39');
    for(let i=0;i<75;i++){
      const placeholder=p.locator('flt-semantics-placeholder');if(await placeholder.count())await placeholder.evaluate(e=>e.click());
      if(await p.getByRole('button',{name:/ · 출격$/}).count())break;
      await p.waitForTimeout(150);
    }
    await p.waitForLoadState('networkidle');
    const launch=p.getByRole('button',{name:/ · 출격$/}).first();
    const box=await reveal(p,launch);
    const background={x:4,y:200,width:5,height:150};
    const button={x:Math.ceil(box.x+box.width*.2),y:Math.ceil(box.y+box.height*.25),width:Math.floor(box.width*.6),height:Math.floor(box.height*.5)};
    const nav=p.getByRole('button',{name:'출격',exact:true});const beforeNav=await nav.boundingBox();
    const sceneryA=await p.screenshot({clip:background}),controlA=await p.screenshot({clip:button});
    await p.screenshot({path:path.join(out,'lobby-before.png')});
    await p.waitForTimeout(2000);
    const sceneryB=await p.screenshot({clip:background}),controlB=await p.screenshot({clip:button});
    await p.screenshot({path:path.join(out,'lobby-after-2s.png')});
    assert(!sceneryA.equals(sceneryB),'scenery must visibly flow');
    assert(controlA.equals(controlB),'painted action must stay unchanged');
    assert.deepEqual(await nav.boundingBox(),beforeNav,'navigation moved');
    assert.deepEqual(await launch.boundingBox(),box,'launch moved');
    await tap(p.getByRole('button',{name:'설정',exact:true}).last());
    await p.getByRole('button',{name:'v10.0.39 · 3초 눌러 개발자 인증',exact:true}).waitFor();
    await p.waitForTimeout(400);
    const coveredA=await p.screenshot({clip:background});await p.waitForTimeout(700);
    assert(coveredA.equals(await p.screenshot({clip:background})),'covered route must freeze scenery');
    await tap(p.getByRole('switch',{name:'시각 효과 줄이기',exact:true}));
    await tap(p.getByRole('button',{name:'닫기',exact:true}).last());
    await p.waitForTimeout(400);
    const reducedA=await p.screenshot({clip:background});await p.waitForTimeout(700);
    assert(reducedA.equals(await p.screenshot({clip:background})),'reduced effects must freeze scenery');
    await tap(p.getByRole('button',{name:'설정',exact:true}).last());
    await tap(p.getByRole('switch',{name:'시각 효과 줄이기',exact:true}));
    await tap(p.getByRole('button',{name:'닫기',exact:true}).last());
    await p.waitForTimeout(400);
    const resumeA=await p.screenshot({clip:background});await p.waitForTimeout(1000);
    assert(!resumeA.equals(await p.screenshot({clip:background})),'motion must resume after effects restored');
    assert.deepEqual(errors,[]);
    const report={version:'v10.0.39',entrypoint:'production',width:390,height:844,visibleBackgroundDrift:true,
      fixedPaintedButton:true,fixedNavigation:true,coveredRouteFrozen:true,reducedEffectsFrozen:true,effectsRestoredMotion:true,errors};
    fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
  }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
