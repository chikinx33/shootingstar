const {chromium}=require('playwright');
const fs=require('fs');const path=require('path');
const assert=require('assert');
const out=path.join(__dirname,'evidence');fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const page=await browser.newPage({viewport:{width:1280,height:900}});
 const errors=[],network=[];page.on('pageerror',e=>errors.push(e.message));page.on('response',r=>{if(r.status()>=400)network.push(r.status()+' '+r.url());});
 await page.route('https://**',r=>r.abort());
 await page.clock.install();
 await page.goto('http://127.0.0.1:8787');await page.waitForTimeout(4500);
 await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());await page.waitForTimeout(300);
 await page.clock.pauseAt(new Date());
 await page.screenshot({path:path.join(out,'01-home.png')});
 await page.getByRole('button',{name:'잔광 외곽 · 출격',exact:true}).click();await page.clock.runFor(400);
 await page.getByRole('button',{name:'비행 준비 완료',exact:true}).click();await page.clock.runFor(600);
 await page.getByRole('button',{name:'일시정지',exact:true}).click();await page.clock.runFor(100);
 const before=(await page.locator('body').ariaSnapshot()).match(/\d\d:\d\d \/ \d\d:\d\d/)[0];await page.clock.runFor(3000);
 assert.equal((await page.locator('body').ariaSnapshot()).match(/\d\d:\d\d \/ \d\d:\d\d/)[0],before,'pause must freeze time');
 await page.getByRole('button',{name:'계속 비행',exact:true}).click();await page.clock.runFor(200);
 const directions=['a','w','d','d','s','s','a','a','w','w','d','s'];
 let choices=0,ended=false;
 for(let i=0;i<280;i++){
   const snapshot=await page.locator('body').ariaSnapshot();
   if(snapshot.includes('집을 지켜 냈다냥!')||snapshot.includes('다음엔 꼭 이긴다냥')){console.log('RESULT',snapshot);ended=true;break;}
   if(snapshot.includes('진화의 갈림길')){
     const pick=page.getByRole('button').filter({hasNotText:'일시정지'}).first();
     if(choices===0){await page.screenshot({path:path.join(out,'03-growth.png')});console.log('GROWTH',snapshot);}
     await pick.click();await page.clock.runFor(100);choices++;
   }
   if(i===12)await page.screenshot({path:path.join(out,'02-battle.png')});
   if(i===20){await page.setViewportSize({width:390,height:844});await page.clock.runFor(200);await page.screenshot({path:path.join(out,'04-mobile-battle.png')});await page.setViewportSize({width:1280,height:900});await page.clock.runFor(200);}
   await page.keyboard.down(directions[i%directions.length]);await page.clock.runFor(1000);await page.keyboard.up(directions[i%directions.length]);
   if(i%30===0)console.log('TICK',i,(await page.locator('body').innerText()).slice(0,220));
 }
 assert(ended,'run should reach result');assert(choices>0,'must choose growth');
 await page.screenshot({path:path.join(out,'05-result.png')});
 const saved=await page.evaluate(()=>localStorage.getItem('flutter.shootingstar.profile.v1'));console.log('SAVE',saved);
 await page.clock.runFor(2000);assert.equal(await page.evaluate(()=>localStorage.getItem('flutter.shootingstar.profile.v1')),saved,'reward does not repeat');
 await page.getByRole('button',{name:'다시 출격',exact:true}).click();await page.clock.runFor(700);
 assert(!(await page.locator('body').innerText()).includes('다음엔 꼭 이긴다냥'));
 await page.getByRole('button',{name:'일시정지',exact:true}).click();await page.clock.runFor(100);
 await page.getByRole('button',{name:'귀환 · 현재 보상 정산',exact:true}).click();await page.clock.runFor(300);
 await page.getByRole('button',{name:'격납고로 귀환',exact:true}).click();await page.clock.runFor(500);
 const savedFinal=await page.evaluate(()=>localStorage.getItem('flutter.shootingstar.profile.v1'));
 await page.clock.resume();await page.reload();await page.waitForTimeout(2500);
 if(await page.locator('flt-semantics-placeholder').count())await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());await page.waitForTimeout(400);
 assert.equal(await page.evaluate(()=>localStorage.getItem('flutter.shootingstar.profile.v1')),savedFinal,'save restored after reload');
 await page.getByRole('tab',{name:'격납고',exact:true}).click();await page.waitForTimeout(400);await page.screenshot({path:path.join(out,'06-hangar.png')});
 await page.setViewportSize({width:390,height:844});await page.waitForTimeout(500);await page.screenshot({path:path.join(out,'07-mobile-hangar.png')});
 await page.getByRole('tab',{name:'출격',exact:true}).click();await page.waitForTimeout(400);await page.screenshot({path:path.join(out,'08-mobile-home.png')});
 assert.deepEqual(errors,[]);assert.deepEqual(network,[]);
 console.log('PASS choices='+choices+'; pause, growth, result, retry, reward-once, reload, mobile resize, offline remote block.');
 fs.writeFileSync(path.join(out,'result.json'),JSON.stringify({choices,errors,network,profile:JSON.parse(savedFinal)},null,2));
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
