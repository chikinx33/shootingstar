// Uses a real earned save from the earlier three-stage playthrough, never cheats.
const {chromium}=require('playwright');const fs=require('fs');const path=require('path');const assert=require('assert');
const out=path.join(__dirname,'evidence');
(async()=>{
 const earned=JSON.parse(fs.readFileSync(path.join(out,'later-stages.json'),'utf8')).saved;
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const page=await browser.newPage({viewport:{width:1280,height:900}});
 const errors=[],badAssets=[],loaded=new Set();
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{if(m.text().includes('Could not load sprite'))errors.push(m.text());});
 page.on('response',r=>{if(r.url().includes('/art/')){if(r.status()>=400)badAssets.push(r.url());else loaded.add(r.url().split('/').pop());}});
 await page.route('https://**',r=>r.abort());
 await page.addInitScript(value=>{if(location.hostname==='127.0.0.1'&&!localStorage.getItem('flutter.shootingstar.profile.v1'))localStorage.setItem('flutter.shootingstar.profile.v1',value);},earned);
 await page.clock.install();await page.goto('http://127.0.0.1:8787');await page.waitForTimeout(4000);
 await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());await page.waitForTimeout(300);await page.clock.pauseAt(new Date());
 await page.getByRole('tab',{name:'격납고',exact:true}).click();await page.clock.runFor(400);
 await page.getByRole('button',{name:'200 C · 해금',exact:true}).click();await page.clock.runFor(200);
 await page.getByRole('button',{name:'450 C · 해금',exact:true}).click();await page.clock.runFor(500);
 await page.screenshot({path:path.join(out,'art-hangar-three-ships.png')});
 let bossCaptured=false;
 for(const [index,name,pick] of [[2,'bastion',null],[1,'scout',1],[0,'interceptor',0]]){
   if(pick!==null){await page.getByRole('button',{name:'기체 선택',exact:true}).nth(pick).click();await page.clock.runFor(200);}
   await page.getByRole('tab',{name:'출격',exact:true}).click();await page.clock.runFor(200);
   await page.getByRole('button',{name:'45초 훈련',exact:true}).click();await page.clock.runFor(1200);
   await page.keyboard.down('s');await page.clock.runFor(900);await page.keyboard.up('s');
   await page.screenshot({path:path.join(out,`art-${name}-desktop.png`)});
   await page.setViewportSize({width:390,height:844});await page.clock.runFor(200);
   await page.keyboard.down('a');await page.clock.runFor(350);await page.keyboard.up('a');
   await page.screenshot({path:path.join(out,`art-${name}-mobile-rotated.png`)});
   await page.setViewportSize({width:1280,height:900});await page.clock.runFor(200);
   if(index===2){
     let bossFrames=0;
     for(let second=0;second<41;second++){
       const snap=await page.locator('body').ariaSnapshot();
       if(snap.includes('진화의 갈림길')){await page.getByRole('button').filter({hasNotText:'일시정지'}).first().click();await page.clock.runFor(100);}
       if(snap.includes('보스 · 공허의 파수꾼')){
         bossFrames++;
         if(bossFrames>=4&&!bossCaptured){await page.screenshot({path:path.join(out,'art-boss-and-enemies.png')});bossCaptured=true;}
       }
       if(snap.includes('항로를 밝혔습니다')||snap.includes('다음 궤적을 향해'))break;
       await page.clock.runFor(1000);
     }
   }
   const snap=await page.locator('body').ariaSnapshot();
   if(!snap.includes('항로를 밝혔습니다')&&!snap.includes('다음 궤적을 향해')){
     await page.getByRole('button',{name:'일시정지',exact:true}).click();await page.clock.runFor(100);
     await page.getByRole('button',{name:'귀환 · 현재 보상 정산',exact:true}).click();await page.clock.runFor(200);
   }
   await page.getByRole('button',{name:'격납고로 귀환',exact:true}).click();await page.clock.runFor(400);
 }
 for(const name of ['shootingstar_title_art.png','shootingstar_interceptor.png','shootingstar_scout.png','shootingstar_bastion.png','shootingstar_enemy_hunter.png','shootingstar_boss_fortress.png'])assert(loaded.has(name),'Asset requested and loaded: '+name);
 assert(bossCaptured,'Boss rendered on screen');assert.deepEqual(errors,[]);assert.deepEqual(badAssets,[]);
 fs.writeFileSync(path.join(out,'visual-art.json'),JSON.stringify({loaded:[...loaded],bossCaptured,errors,badAssets},null,2));
 console.log('PASS six original PNGs loaded, three ship mappings, rotation/mobile, live boss and enemies, no errors');await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
