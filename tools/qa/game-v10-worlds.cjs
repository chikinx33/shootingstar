// Explicitly posed art coverage for all ten world palettes; never real wins.
const {chromium}=require('playwright'),fs=require('fs'),path=require('path'),assert=require('assert');
(async()=>{const out=path.join(__dirname,'evidence/game-v10'),rows=[],errors=[];let browser;
 try{for(let world=0;world<10;world++){
  console.log('V10 posed world',world+1);
  browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
  const c=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated QA"}'}));
  const p=await c.newPage();p.on('pageerror',e=>errors.push(e.stack));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
  await p.goto(`http://127.0.0.1:8798/?scene=art-v10&stage=${world*10}&ship=${world%3}&pet=${world%3}&textScale=1.3`);
  let ready=false;for(let i=0;i<200;i++){if(await p.locator('flt-semantics-placeholder').count())await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());if(await p.getByRole('button',{name:'일시정지',exact:true}).count()){ready=true;break;}await p.waitForTimeout(200);}
  assert(ready);await p.waitForTimeout(600);assert.equal(await p.locator('flt-semantics-scroll-overflow').count(),0);
  await p.screenshot({path:path.join(out,`fixture-world-${world+1}-390-scale-1.3.png`)});
  rows.push({world:world+1,stage:world*10,ship:world%3,pet:world%3,scale:1.3,posedFixture:true});await c.close();await browser.close();
 }assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,'world-fixtures-result.json'),JSON.stringify({rows,errors,scope:'Posed art fixtures for background/enemy/pet/weapon/passive coverage. No earned progress or boss victories claimed.'},null,2));console.log('10 posed world renders passed');
 }finally{if(browser)await browser.close();}
})();
